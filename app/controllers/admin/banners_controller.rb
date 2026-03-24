module Admin
  class BannersController < BaseController
    before_action :set_banner, only: [:edit, :update, :destroy, :toggle, :move]

    def index
      @banners = Banner.ordered
    end

    def new
      @banner = Banner.new(position: "after_result", page: "all", banner_type: "internal")
    end

    def create
      @banner = Banner.new(banner_params)
      @banner.sort_order = (Banner.maximum(:sort_order) || 0) + 1

      if @banner.save
        redirect_to admin_banners_path, notice: "Banner created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @banner.update(banner_params)
        redirect_to admin_banners_path, notice: "Banner updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @banner.destroy
      redirect_to admin_banners_path, notice: "Banner deleted."
    end

    def toggle
      @banner.update(active: !@banner.active)
      redirect_to admin_banners_path
    end

    def move
      direction = params[:direction]
      if direction == "up" && @banner.sort_order > 0
        swap = Banner.where("sort_order < ?", @banner.sort_order).order(sort_order: :desc).first
        swap_order(swap)
      elsif direction == "down"
        swap = Banner.where("sort_order > ?", @banner.sort_order).order(:sort_order).first
        swap_order(swap)
      end
      redirect_to admin_banners_path
    end

    private

    def set_banner
      @banner = Banner.find(params[:id])
    end

    def banner_params
      params.require(:banner).permit(
        :title_en, :title_ko, :description_en, :description_ko,
        :link_url, :button_text_en, :button_text_ko, :image_url,
        :position, :page, :active, :sort_order, :banner_type, :adsense_slot_id
      )
    end

    def swap_order(other)
      return unless other
      Banner.transaction do
        old_order = @banner.sort_order
        @banner.update!(sort_order: other.sort_order)
        other.update!(sort_order: old_order)
      end
    end
  end
end
