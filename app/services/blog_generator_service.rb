class BlogGeneratorService
  API_URL = "https://api.anthropic.com/v1/messages"
  MODEL = "claude-sonnet-4-20250514"

  def generate_post(topic_ko, category)
    prompt = <<~PROMPT
      당신은 SlimFile(slimfile.net)이라는 무료 온라인 파일 변환 도구의 블로그 작성자입니다.
      SlimFile는 이미지 압축, PDF 변환, SNS 리사이즈 기능을 제공합니다.

      다음 주제로 SEO에 최적화된 블로그 포스트를 작성하세요:
      주제: #{topic_ko}
      카테고리: #{category}

      반드시 아래 JSON 형식으로만 응답하세요 (다른 텍스트 없이):
      {
        "title_ko": "한국어 제목 (50자 이내, SEO 키워드 포함)",
        "body_ko": "한국어 본문 (HTML 형식, h2/h3/p/ul/li/strong 태그 사용, 1500자 이상, 실용적 팁 포함)",
        "meta_description_ko": "메타 설명 (155자 이내)",
        "slug": "영문-슬러그-형식",
        "cover_svg": "<svg> 태그로 시작하는 인포그래픽 SVG (Before/After 비교 또는 숫자 통계, viewBox='0 0 800 400', 깔끔한 모던 디자인, #0A6E8A 주요색)"
      }

      본문 작성 가이드:
      - 실제 사용자가 검색할만한 키워드를 자연스럽게 포함
      - 구체적인 숫자와 비교를 포함 (예: 5MB → 500KB)
      - SlimFile 서비스를 자연스럽게 언급하되 과도한 광고는 피하기
      - 실용적인 단계별 가이드 형식 선호
    PROMPT

    response = call_api(prompt)
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

  def call_api(prompt)
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
      max_tokens: 4096,
      messages: [{ role: "user", content: prompt }]
    }.to_json

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

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
