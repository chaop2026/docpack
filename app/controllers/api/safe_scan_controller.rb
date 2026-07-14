# app/controllers/api/safe_scan_controller.rb
#
# SafeFile의 "AI 정밀 검사"를 중계하는 엔드포인트.
# 브라우저 → 이 컨트롤러 → Anthropic API 순서로 흘러가며,
# API 키는 서버 환경변수(ANTHROPIC_API_KEY)에만 존재한다.
#
# 요청:  POST /api/safe_scan
#        { "text": "문서 내용" }                          — 텍스트 검사
#        { "image": { "data": "<base64>", "media": "image/png" } } — 이미지 검사(OCR 포함)
# 응답:  { "raw": "<모델이 출력한 JSON 문자열>" }
#
require "net/http"

module Api
  class SafeScanController < ApplicationController
    skip_before_action :verify_authenticity_token

    ANTHROPIC_URL = "https://api.anthropic.com/v1/messages".freeze
    # 비용 최적화: 개인정보 추출은 소형 모델로 충분하다.
    MODEL         = "claude-haiku-4-5-20251001".freeze
    MAX_TEXT      = 8_000          # 문자 수 제한 (약 1~2페이지)
    MAX_IMAGE_B64 = 7_000_000      # base64 기준 약 5MB
    HOURLY_LIMIT  = 30             # IP당 시간당 AI 검사 횟수

    TEXT_PROMPT = <<~PROMPT.freeze
      다음 문서에서 개인정보를 모두 찾아라. 특히 사람 이름, 회사·기관명, 직책, 주소,
      건강 관련 정보처럼 패턴이 없는 것들. 반드시 JSON 배열만 출력하라. 마크다운·설명 금지.
      형식: [{"type":"name|phone|email|rrn|ssn|passport|license|card|account|birth|address|company|title|ip|url|health|other","value":"문서에 나온 원문 그대로"}]

      문서:
      """
      %<doc>s
      """
    PROMPT

    IMAGE_PROMPT = <<~PROMPT.freeze
      이 이미지 문서에서 (1) 전체 텍스트를 추출하고 (2) 개인정보를 찾아라.
      반드시 아래 JSON만 출력하라. 마크다운 금지.
      {"text":"추출한 전체 텍스트","entities":[{"type":"name|phone|email|rrn|ssn|passport|license|card|account|birth|address|company|title|ip|url|health|other","value":"원문 그대로"}]}
    PROMPT

    def create
      return render(json: { error: "rate_limited" },  status: 429) if throttled?

      text  = params[:text].to_s
      image = params[:image]

      if image.present? && image[:data].present?
        return render(json: { error: "image_too_large" }, status: 413) if image[:data].length > MAX_IMAGE_B64
        content = [
          { type: "image", source: { type: "base64", media_type: image[:media].presence || "image/png", data: image[:data] } },
          { type: "text",  text: IMAGE_PROMPT }
        ]
        max_tokens = 3_000   # OCR 텍스트까지 돌려받아야 하므로 여유
      elsif text.present?
        return render(json: { error: "text_too_long" }, status: 413) if text.length > MAX_TEXT
        content    = [{ type: "text", text: format(TEXT_PROMPT, doc: text) }]
        max_tokens = 1_500
      else
        return render(json: { error: "empty" }, status: 400)
      end

      raw = call_anthropic(content, max_tokens)
      render json: { raw: raw }
    rescue StandardError => e
      Rails.logger.error("[safe_scan] #{e.class}: #{e.message}")
      render json: { error: "upstream" }, status: 502
    end

    private

    def call_anthropic(content, max_tokens)
      uri  = URI(ANTHROPIC_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = 10
      http.read_timeout = 60

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"]         = ENV.fetch("ANTHROPIC_API_KEY")
      req["anthropic-version"] = "2023-06-01"
      req["content-type"]      = "application/json"
      req.body = {
        model:      MODEL,
        max_tokens: max_tokens,
        messages:   [{ role: "user", content: content }]
      }.to_json

      res = http.request(req)
      raise "anthropic #{res.code}" unless res.code.to_i == 200

      body = JSON.parse(res.body)
      Array(body["content"]).select { |c| c["type"] == "text" }.map { |c| c["text"] }.join("\n")
    end

    # 별도 gem 없이 Rails.cache로 구현한 IP당 시간 단위 사용량 제한.
    # (Rack::Attack을 이미 쓰고 있다면 그쪽으로 옮겨도 된다)
    def throttled?
      key   = "safe_scan:#{request.remote_ip}:#{Time.current.strftime('%Y%m%d%H')}"
      count = Rails.cache.read(key).to_i + 1
      Rails.cache.write(key, count, expires_in: 1.hour)
      count > HOURLY_LIMIT
    end
  end
end
