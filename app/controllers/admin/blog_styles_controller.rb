require "net/http"
require "json"
require "uri"

module Admin
  class BlogStylesController < BaseController
    before_action :set_blog_style, only: [:show, :edit, :update, :destroy, :analyze, :toggle]

    def index
      @blog_styles = BlogStyle.order(created_at: :desc)
      @active_styles = @blog_styles.where(is_active: true)
    end

    def new
      @blog_style = BlogStyle.new
    end

    def create
      @blog_style = BlogStyle.new(blog_style_params)
      if @blog_style.save
        redirect_to admin_blog_styles_path, notice: "전략이 저장되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def edit
    end

    def update
      if @blog_style.update(blog_style_params)
        redirect_to admin_blog_style_path(@blog_style), notice: "전략이 수정되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @blog_style.destroy
      redirect_to admin_blog_styles_path, notice: "전략이 삭제되었습니다."
    end

    def analyze
      raw = @blog_style.raw_script
      if raw.blank?
        redirect_to admin_blog_style_path(@blog_style), alert: "분석할 스크립트가 없습니다."
        return
      end

      result = analyze_with_claude(raw)
      if result
        @blog_style.update!(
          hooking_patterns: result["hooking_patterns"].to_json,
          sentence_structure: result["sentence_structure"].to_json,
          psychological_triggers: result["psychological_triggers"].to_json,
          tone_style: result["tone_style"].to_json
        )
        redirect_to admin_blog_style_path(@blog_style), notice: "Claude 분석이 완료되었습니다."
      else
        redirect_to admin_blog_style_path(@blog_style), alert: "Claude API 분석에 실패했습니다."
      end
    end

    def toggle
      @blog_style.update!(is_active: !@blog_style.is_active)
      redirect_to admin_blog_styles_path, notice: "#{@blog_style.source_name} #{@blog_style.is_active? ? '활성화' : '비활성화'}됨."
    end

    private

    def set_blog_style
      @blog_style = BlogStyle.find(params[:id])
    end

    def blog_style_params
      params.require(:blog_style).permit(
        :source_name, :raw_script, :hooking_patterns, :sentence_structure,
        :psychological_triggers, :tone_style, :is_active, :notes
      )
    end

    def analyze_with_claude(raw_script)
      api_key = ENV["ANTHROPIC_API_KEY"]
      return nil if api_key.blank?

      system_prompt = "당신은 마케팅 카피라이팅 전문가입니다.\n입력된 스크립트/텍스트에서 블로그 글쓰기에 활용할 수 있는\n마케팅 패턴을 추출합니다.\n반드시 JSON 형식으로만 응답하세요."

      user_prompt = <<~PROMPT
        다음 스크립트를 분석해서 블로그 글쓰기 전략으로 활용할 수 있는
        요소들을 추출해주세요.

        스크립트:
        #{raw_script}

        다음 JSON 형식으로 응답하세요:
        {
          "hooking_patterns": [
            {"pattern": "패턴 설명", "example": "예시 문구", "when_to_use": "언제 사용"}
          ],
          "sentence_structure": [
            {"feature": "특징 설명", "example": "예시"}
          ],
          "psychological_triggers": [
            {"trigger": "심리 트리거명", "description": "설명", "example": "예시"}
          ],
          "tone_style": {
            "overall_tone": "전반적 톤 설명",
            "key_characteristics": ["특징1", "특징2", "특징3"],
            "avoid": ["피해야 할 것1", "피해야 할 것2"]
          }
        }
      PROMPT

      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 120

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["x-api-key"] = api_key
      request["anthropic-version"] = "2023-06-01"
      request.body = {
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        system: system_prompt,
        messages: [{ role: "user", content: user_prompt }]
      }.to_json

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("BlogStyle analyze error: #{response.code} #{response.body}")
        return nil
      end

      data = JSON.parse(response.body)
      text = data.dig("content", 0, "text")
      return nil if text.blank?

      json_match = text.match(/\{[\s\S]*\}/m)
      return nil unless json_match

      JSON.parse(json_match[0])
    rescue StandardError => e
      Rails.logger.error("BlogStyle analyze error: #{e.message}")
      nil
    end
  end
end
