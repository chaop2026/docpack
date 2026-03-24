module BannersHelper
  def render_banners(page:, position: "after_result")
    banners = Banner.active.for_page(page).for_position(position).ordered
    return if banners.empty?

    render partial: "shared/banners", locals: { banners: banners }
  end
end
