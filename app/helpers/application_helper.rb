module ApplicationHelper
  def base_url
    ENV.fetch("BASE_URL", "https://docpack.app")
  end

  def page_meta(title:, description:, path: request.path, image: nil)
    content_for(:meta_title, title)
    content_for(:meta_description, description)
    content_for(:meta_url, "#{base_url}#{path}")
    content_for(:meta_image, image || "#{base_url}/icon.png")
  end
end
