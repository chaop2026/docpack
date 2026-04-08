require "net/http"
require "json"
require "uri"

class BlogGeneratorService
  API_URL = "https://api.anthropic.com/v1/messages"
  MODEL = "claude-sonnet-4-20250514"

  SYSTEM_PROMPT = <<~SYSTEM.freeze
    당신은 파일 압축/변환 분야의 심리 마케팅 전문 블로그 작가입니다.
    독자는 지금 당장 파일 문제를 해결해야 하는 긴박한 상황입니다.
    글의 목표는 정보 전달이 아니라 공감 → 신뢰 → 행동 유도입니다.

    핵심 원칙:
    1. 첫 문장은 반드시 독자가 "맞아, 나 이거야!"를 느끼는 구체적 상황 묘사
    2. 모든 설명에 구체적 숫자 포함 (막연한 표현 금지)
    3. 손실 프레이밍: 얻는 것보다 지금 잃고 있는 것을 먼저 보여줌
    4. CTA는 손실 프레이밍 직후와 글 말미, 두 곳에 삽입
    5. FAQ는 독자가 머릿속에서 하는 반박을 선제적으로 해소
    6. 반드시 JSON으로만 응답. 마크다운 코드블록 없이 순수 JSON
  SYSTEM

  def generate_post(topic, category)
    prompt = build_generate_prompt(topic, category)
    system = build_system_prompt
    response = call_api(prompt, system)
    parse_json_response(response)
  end

  def improve_post(post, instruction)
    prompt = <<~PROMPT
      아래 블로그 포스트를 다음 지시에 따라 수정하세요:

      수정 지시: #{instruction}

      현재 제목: #{post.title_ko}
      현재 본문:
      #{post.body_ko}

      반드시 아래 JSON 형식으로만 응답하세요 (다른 텍스트 없이):
      {
        "title_ko": "수정된 한국어 제목",
        "body_ko": "수정된 한국어 본문 (HTML 형식)",
        "meta_description_ko": "수정된 메타 설명"
      }
    PROMPT

    response = call_api(prompt)
    parse_json_response(response)
  end

  private

  def build_system_prompt
    base = SYSTEM_PROMPT.dup
    active_styles = BlogStyle.where(is_active: true).order(created_at: :desc).limit(3)
    return base if active_styles.empty?

    styles_summary = active_styles.map do |style|
      summary = "출처: #{style.source_name}\n"
      if style.hooking_patterns.present?
        begin
          hooks = JSON.parse(style.hooking_patterns)
          patterns = hooks.map { |h| h["pattern"] }.compact.join(", ")
          summary += "- 후킹 패턴: #{patterns}\n"
        rescue JSON::ParserError
        end
      end
      if style.psychological_triggers.present?
        begin
          triggers = JSON.parse(style.psychological_triggers)
          trigger_names = triggers.map { |t| t["trigger"] }.compact.join(", ")
          summary += "- 심리 트리거: #{trigger_names}\n"
        rescue JSON::ParserError
        end
      end
      if style.tone_style.present?
        begin
          tone = JSON.parse(style.tone_style)
          summary += "- 톤: #{tone["overall_tone"]}\n"
        rescue JSON::ParserError
        end
      end
      summary
    end.join("\n")

    base + <<~ADDITION

      [참고할 글쓰기 전략]
      #{styles_summary}

      위 전략의 패턴과 심리 트리거를 자연스럽게 녹여서 블로그 포스트를 작성하세요.
      단, 억지로 끼워넣지 말고 글의 흐름에 맞게 자연스럽게 활용하세요.
    ADDITION
  end

  def build_generate_prompt(topic, category)
    <<~PROMPT
      주제: #{topic}
      카테고리: #{category}
      서비스: SlimFile (https://slimfile.net)

      다음 JSON 형식으로 블로그 포스트를 작성해주세요:

      {
        "title_ko": "독자의 고통을 찌르는 제목 — 의문문 또는 긴박한 상황 묘사, 30자 이내",
        "subtitle_ko": "제목을 보완하는 공감 문장, 25자 이내",
        "meta_description_ko": "검색 결과 요약, 160자 이내, 핵심 키워드 포함",
        "slug": "영문-kebab-case",
        "trust_bar": "오늘 {숫자}명이 SlimFile로 파일을 압축했어요 · 무료 · 회원가입 불필요 · 30초 완료",
        "pain_tag": "카테고리에 맞는 긴급 태그 (예: PDF 긴급 해결, 이미지 즉시 압축)",
        "error_mockup": {
          "url_bar": "실제 서비스 URL (예: mail.google.com, instagram.com)",
          "service_name": "서비스명 (예: Gmail, Instagram)",
          "service_icon_letter": "첫글자 (예: G, I)",
          "service_icon_color": "브랜드 색상 hex",
          "error_title": "실제 에러 메시지",
          "error_desc": "에러 상세 설명 (구체적 수치 포함)",
          "file_name": "실제 파일명 예시 (예: 2026_Q1_보고서.pdf)",
          "file_size": "파일 크기 (예: 34.2MB)",
          "size_label": "크기 배지 텍스트 (예: 34.2MB 초과)"
        },
        "recognition_text": "독자 상황 공감 + 해결 가능성 암시 (2~3문장, 구체적 수치 포함)",
        "loss_items": [
          "구체적 손실 상황 1",
          "구체적 손실 상황 2",
          "구체적 손실 상황 3",
          "구체적 손실 상황 4"
        ],
        "stats": [
          {"num": "90%", "label": "평균 용량\\n감소율"},
          {"num": "30초", "label": "평균 압축\\n소요 시간"},
          {"num": "수치", "label": "주제에 맞는\\n세번째 통계"}
        ],
        "body_ko": "cause, steps, situations, checklist, faq 섹션을 포함한 HTML 본문 (아래 구조 참조)",
        "cover_svg": "viewBox=0 0 600 280, Before/After 비교 SVG"
      }

      body_ko HTML 구조 (반드시 이 순서로, 각 섹션에 적절한 CSS 클래스 사용):

      <h2>{원인 섹션 제목}</h2>
      <div class="blog-cause-list">
        3개의 원인 카드. 각각:
        <div class="blog-cause-card">
          <div class="blog-cause-num">{번호}</div>
          <div><strong>{원인 제목}</strong><p>{구체적 설명, 수치 포함}</p></div>
        </div>
      </div>

      <h2>{SlimFile로 해결하는 단계 제목}</h2>
      <div class="blog-steps-v2">
        3단계. 각각:
        <div class="blog-step">
          <div class="blog-step-num">{번호}</div>
          <div><strong>{단계 제목}</strong><p>{설명}</p><span class="blog-step-tip">{소요 시간 또는 팁}</span></div>
        </div>
      </div>

      <div class="blog-ba-wrap">
        <div class="blog-ba-title">Before vs After</div>
        <div class="blog-ba-grid">
          <div class="blog-ba-before">
            <div class="blog-ba-label">BEFORE</div>
            <div class="blog-ba-size">{압축 전 크기}</div>
            <div class="blog-ba-sub">{상태}</div>
          </div>
          <div class="blog-ba-arrow">→<span class="blog-ba-pct">{감소율}</span></div>
          <div class="blog-ba-after">
            <div class="blog-ba-label">AFTER</div>
            <div class="blog-ba-size">{압축 후 크기}</div>
            <div class="blog-ba-sub">{상태}</div>
          </div>
        </div>
      </div>

      <h2>상황별 추천 설정</h2>
      <div class="blog-situation-grid">
        4가지 상황 카드. 각각:
        <div class="blog-situation-card">
          <h3>{상황 제목}</h3>
          <ul>
            <li><span class="blog-situation-arrow">→</span>{항목}</li>
          </ul>
        </div>
      </div>

      <div class="blog-checklist-v2">
        <div class="blog-checklist-head">전송 전 체크리스트</div>
        5개 항목. 각각:
        <div class="blog-checklist-item"><span class="blog-check-icon">✓</span>{체크 항목}</div>
      </div>

      <div class="blog-faq-v2">
        4개 FAQ. 각각:
        <div class="blog-faq-item-v2">
          <div class="blog-faq-q-v2"><span class="blog-faq-badge">Q</span>{질문}</div>
          <div class="blog-faq-a-v2">{답변}</div>
        </div>
      </div>

      cover_svg 기준:
      - viewBox="0 0 600 280"
      - 주제에 맞는 한국어 제목 (상단)
      - Before 박스 (#FCEBEB 배경, #A32D2D 텍스트) → SlimFile 화살표 (#0A6E8A) → After 박스 (#EAF3DE 배경, #3B6D11 텍스트)
      - 하단: 혜택 3가지 (속도향상, 용량절약, 화질유지)
      - 전체 배경: #F8F7F4, 폰트: sans-serif, 한국어
    PROMPT
  end

  def call_api(prompt, system = SYSTEM_PROMPT)
    api_key = ENV["ANTHROPIC_API_KEY"]
    return nil if api_key.blank?

    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"
    request.body = {
      model: MODEL,
      max_tokens: 8192,
      system: system,
      messages: [{ role: "user", content: prompt }]
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("BlogGeneratorService API error: #{response.code} #{response.body}")
      return nil
    end

    data = JSON.parse(response.body)
    data.dig("content", 0, "text")
  rescue StandardError => e
    Rails.logger.error("BlogGeneratorService error: #{e.message}")
    nil
  end

  def parse_json_response(text)
    return nil if text.blank?

    json_match = text.match(/\{[\s\S]*\}/m)
    return nil unless json_match

    result = JSON.parse(json_match[0])
    parsed = result.transform_keys(&:to_sym)

    # Serialize nested JSON fields
    parsed[:error_mockup] = parsed[:error_mockup].to_json if parsed[:error_mockup].is_a?(Hash)
    parsed[:loss_items] = parsed[:loss_items].to_json if parsed[:loss_items].is_a?(Array)
    parsed[:stats] = parsed[:stats].to_json if parsed[:stats].is_a?(Array)

    parsed.slice(
      :title_ko, :subtitle_ko, :body_ko, :meta_description_ko, :slug, :cover_svg,
      :trust_bar, :pain_tag, :error_mockup, :recognition_text, :loss_items, :stats
    )
  rescue JSON::ParserError => e
    Rails.logger.error("BlogGeneratorService JSON parse error: #{e.message}")
    nil
  end
end
