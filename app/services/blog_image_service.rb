require "net/http"
require "json"
require "uri"

class BlogImageService
  CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
  CLAUDE_MODEL = "claude-sonnet-4-20250514"

  # Claude가 문제 상황을 재현하는 고품질 SVG 히어로 이미지를 생성
  def generate_for_post(post)
    svg_content = generate_hero_svg(post)
    return nil if svg_content.blank?

    attach_to_post(post, svg_content)
  end

  private

  def generate_hero_svg(post)
    api_key = ENV["ANTHROPIC_API_KEY"]
    return nil if api_key.blank?

    system = <<~SYS
      당신은 웹 SVG 일러스트레이션 전문가입니다.
      블로그 포스트의 히어로 이미지로 사용할 고품질 SVG를 생성합니다.
      반드시 <svg>...</svg> 태그만 출력하세요. 다른 텍스트 없이.
    SYS

    # error_mockup 데이터 파싱
    mockup_info = ""
    if post.error_mockup.present?
      begin
        m = JSON.parse(post.error_mockup)
        mockup_info = <<~INFO
          에러 목업 정보:
          - 서비스: #{m['service_name']} (#{m['url_bar']})
          - 에러: #{m['error_title']}
          - 파일: #{m['file_name']} (#{m['file_size']})
        INFO
      rescue JSON::ParserError
      end
    end

    user_prompt = <<~PROMPT
      블로그 포스트 정보:
      - 제목: #{post.title_ko}
      - 부제: #{post.subtitle_ko}
      - 카테고리: #{post.category}
      - 페인 태그: #{post.pain_tag}
      #{mockup_info}

      이 블로그의 히어로 이미지를 SVG로 생성해주세요.

      === SVG 요구사항 ===

      viewBox: 0 0 800 420
      전체 배경: #F8F7F4

      이미지 구성 (상단 → 하단):

      [1. 상단 60% — 문제 상황 재현 화면]
      노트북/브라우저 목업 안에 실제 에러 상황을 재현:
      - 브라우저 상단바 (빨/노/초 dots + URL bar)
      - 에러 팝업: 빨간 배경(#FCEBEB) + 경고 아이콘 + 에러 메시지
      - 파일 정보: 파일 아이콘 + 파일명 + 빨간 사이즈 배지
      - 이 부분이 핵심! 독자가 "아, 이 에러 나도 본 적 있어!"라고 느껴야 함
      - 실제 서비스(Gmail, 카카오톡 등)의 UI 느낌을 반영

      [2. 하단 40% — 해결 후 결과]
      - 좌측: Before 박스 (#FCEBEB 배경, 큰 파일 크기, ❌ 전송 불가)
      - 중앙: SlimFile 로고/화살표 (#0A6E8A)
      - 우측: After 박스 (#EAF3DE 배경, 작은 파일 크기, ✅ 전송 성공)
      - 감소율 표시

      === 디자인 가이드라인 ===
      - 모든 텍스트: sans-serif, 한국어
      - 라운드 코너: rx="8~12"
      - 그림자 효과: filter로 drop-shadow 사용
      - 색상 체계:
        - 에러/위험: #FCEBEB, #A32D2D, #E24B4A
        - 성공/해결: #EAF3DE, #3B6D11
        - 브랜드(SlimFile): #0A6E8A
        - 중립: #F8F7F4, #E5E3DC, #6B6963
      - 깔끔하고 모던한 플랫 디자인
      - 너무 복잡하지 않게, 핵심 요소만 명확하게

      <svg> 태그만 출력하세요. 완전한 SVG여야 합니다.
    PROMPT

    uri = URI(CLAUDE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"
    request.body = {
      model: CLAUDE_MODEL,
      max_tokens: 8192,
      system: system,
      messages: [{ role: "user", content: user_prompt }]
    }.to_json

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    text = data.dig("content", 0, "text").to_s.strip

    # SVG 추출
    svg_match = text.match(/<svg[\s\S]*<\/svg>/m)
    return nil unless svg_match

    svg = svg_match[0]
    Rails.logger.info("BlogImageService: SVG generated (#{svg.length} chars)")
    svg
  rescue StandardError => e
    Rails.logger.error("BlogImageService SVG error: #{e.message}")
    nil
  end

  # SVG를 Active Storage에 첨부
  def attach_to_post(post, svg_content)
    filename = "hero-#{post.slug || post.id}-#{Time.current.to_i}.svg"
    post.hero_image.attach(
      io: StringIO.new(svg_content),
      filename: filename,
      content_type: "image/svg+xml"
    )
    Rails.logger.info("BlogImageService: SVG attached to post #{post.id} (#{filename})")
    true
  rescue StandardError => e
    Rails.logger.error("BlogImageService attach error: #{e.message}")
    false
  end
end
