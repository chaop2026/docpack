class PostsController < ApplicationController
  def index
    @posts = Post.published.recent
    @posts = @posts.by_category(params[:category]) if params[:category].present?

    helpers.page_meta(
      title: t("blog.title"),
      description: t("blog.meta_description"),
      path: "/blog"
    )
  end

  def show
    @post = Post.published.find_by!(slug: params[:slug])
    @post.increment!(:view_count)
    @related_posts = Post.published.where(category: @post.category).where.not(id: @post.id).recent.limit(3)

    helpers.page_meta(
      title: @post.title,
      description: @post.meta_description.presence || @post.title,
      path: "/blog/#{@post.slug}"
    )
  end
end
