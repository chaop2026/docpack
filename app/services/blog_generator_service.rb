require "net/http"
require "json"
require "uri"

class BlogGeneratorService
  API_URL = "https://api.anthropic.com/v1/messages"
  MODEL = "claude-sonnet-4-20250514"

  SYSTEM_PROMPT = <<~SYSTEM.freeze
    당신은 파일 압축/변환 분야의 심리 마케팅 전문 블로그 작가입니다.
    독자는 지금 당장 파일 문제를 해결해야 하는 긴박한 상황에 있습니다.
    글의 목표는 정보 전달이 아니라 '행동 유도'입니다.

    핵심 원칙:
    1. 첫 문장은 반드시 독자의 고통을 찌르는 질문이나 상황 묘사로 시작
    2. 추상적 표현 금지 — 모든 설명에 구체적 숫자 포함
    3. "얻는 것"보다 "지금 잃고 있는 것"을 먼저 보여줌
    4. CTA는 문제 인식 직후와 글 말미, 두 곳에 자연스럽게 삽입
    5. FAQ는 실제 독자가 머릿속으로 하는 반박을 선제적으로 해소
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

      다음 구조로 HTML 블로그 포스트를 작성해주세요.
      반드시 JSON으로만 응답하고, 마크다운 코드블록 없이 순수 JSON만 출력하세요.

      {
        "title_ko": "독자의 고통을 찌르는 제목 (의문문 또는 긴박한 상황 묘사, 30자 이내)",
        "meta_description_ko": "검색 결과에 표시될 요약 (160자 이내, 핵심 키워드 포함)",
        "slug": "영문-kebab-case-url",
        "body_ko": "아래 구조를 따른 HTML",
        "cover_svg": "아래 기준의 SVG 코드"
      }

      body_ko HTML 구조 (반드시 이 순서로):

      <section class="blog-intro">
      [1. 도입 — 고통 공감 (2~3문장)]
      독자가 겪는 구체적 상황을 묘사. 반드시 실제 겪을 법한 상황으로.
      예: "중요한 계약서를 이메일로 보내려는데 '파일이 너무 큽니다' 오류가 떴나요?"
      숫자 포함 필수.
      </section>

      <section class="blog-loss">
      <h2>지금 이 문제를 방치하면 잃게 되는 것</h2>
      [손실 목록 — ul/li로 4가지]
      구체적인 손실 상황. 추상적 표현 금지.
      예: <li>25MB 첨부 제한에 걸려 마감 시간을 놓칠 위험</li>
      </section>

      <section class="blog-cta-inline">
      <a href="https://slimfile.net" class="cta-link">지금 바로 해결하기 → 무료 · 회원가입 불필요 · 30초 완료</a>
      </section>

      <section class="blog-stats">
      [핵심 수치 3가지 — 구체적 숫자로]
      <div class="stat-item"><span class="stat-num">90%</span><span class="stat-label">평균 용량 감소율</span></div>
      형식으로 3개 작성
      </section>

      <section class="blog-cause">
      <h2>왜 이런 문제가 생기나요?</h2>
      [원인 3가지 — 각각 h3 제목 + p 설명, 구체적 수치 포함]
      </section>

      <section class="blog-steps">
      <h2>SlimFile로 30초 해결하는 방법</h2>
      [단계별 ol/li, 3단계, 각 단계에 소요 시간 명시]
      </section>

      <section class="blog-situations">
      <h2>상황별 추천 설정</h2>
      [4가지 상황 카드 — div.situation-card로]
      이메일 첨부 / 과제 제출 / 포트폴리오 / 장기 보관
      각 카드: 목표 크기, 추천 압축 수준, 평균 감소율 포함
      </section>

      <section class="blog-checklist">
      <h2>전송 전 체크리스트</h2>
      [ul/li 5가지 체크 항목]
      </section>

      <section class="blog-faq">
      <h2>자주 묻는 질문</h2>
      [4개 Q&A — 각각 div.faq-item > h3.faq-q + p.faq-a]
      Q: 화질이 떨어지지 않나요?
      Q: 내 파일이 외부에 저장되나요?
      Q: 압축 후에도 너무 크면요?
      Q: 모바일에서도 되나요?
      </section>

      <section class="blog-cta-bottom">
      <a href="https://slimfile.net" class="cta-link">SlimFile에서 무료로 해결하기 →</a>
      </section>

      cover_svg 기준:
      - viewBox="0 0 600 280"
      - 주제에 맞는 한국어 제목 텍스트 (상단)
      - Before 박스 (빨간 계열 #FCEBEB 배경, #A32D2D 텍스트): 압축 전 수치, 상태 설명 2줄
      - → 화살표 중앙: "SlimFile" 텍스트 (#0A6E8A)
      - After 박스 (초록 계열 #EAF3DE 배경, #3B6D11 텍스트): 압축 후 수치, 감소율
      - 하단: 혜택 3가지 아이콘 (속도향상, 용량절약, 화질유지)
      - 전체 배경: #F8F7F4
      - 폰트: sans-serif
      - SVG 내 모든 텍스트는 한국어
      - <svg> 태그로 시작, 닫는 </svg>로 끝나는 완전한 SVG
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

    json_match = text.match(/\{[\s\S]*\}/)
    return nil unless json_match

    result = JSON.parse(json_match[0])
    result.transform_keys(&:to_sym).slice(:title_ko, :body_ko, :meta_description_ko, :slug, :cover_svg)
  rescue JSON::ParserError => e
    Rails.logger.error("BlogGeneratorService JSON parse error: #{e.message}")
    nil
  end
end
