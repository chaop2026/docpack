class ImageCompressor
  TARGET_SIZE = 2.megabytes

  # Compression strategies: [scale, quality] pairs ordered from aggressive to gentle
  STRATEGIES = [
    [0.2, 10], [0.25, 10], [0.25, 15], [0.3, 15], [0.3, 20],
    [0.35, 20], [0.35, 25], [0.4, 25], [0.4, 30], [0.5, 20],
    [0.5, 30], [0.5, 40], [0.6, 30], [0.6, 40], [0.75, 25],
    [0.75, 35], [0.75, 50], [1.0, 15], [1.0, 25], [1.0, 35],
    [1.0, 50], [1.0, 65], [1.0, 80]
  ].freeze

  def initialize(source, target_percent: nil)
    @source = source
    @target_percent = target_percent&.to_i
  end

  def call
    path = @source.is_a?(String) ? @source : @source.path
    original_size = File.size(path)
    width, height = vips_dimensions(path)

    if @target_percent && @target_percent.between?(1, 100)
      target_bytes = (original_size * @target_percent / 100.0).to_i
      compress_to_target(path, target_bytes, width, height)
    else
      auto_compress(path, original_size, width, height)
    end
  end

  private

  def compress_to_target(path, target_bytes, width, height)
    STRATEGIES.each do |scale, quality|
      w = (width * scale).to_i
      h = (height * scale).to_i

      pipeline = ImageProcessing::Vips.source(path)
      pipeline = pipeline.resize_to_limit(w, h) if scale < 1.0
      result = pipeline.convert("jpeg").saver(quality: quality, strip: true, interlace: true).call

      return result if result.size <= target_bytes

      result.close!
    end

    # Fallback: most aggressive
    ImageProcessing::Vips.source(path)
      .resize_to_limit(width / 5, height / 5)
      .convert("jpeg")
      .saver(quality: 10, strip: true, interlace: true)
      .call
  end

  def auto_compress(path, original_size, width, height)
    [80, 65, 50].each do |q|
      result = compress(path, quality: q)
      return result if good_enough?(result, original_size)
    end

    ImageProcessing::Vips.source(path)
      .resize_to_limit(width / 2, height / 2)
      .convert("jpeg")
      .saver(quality: 50, strip: true, interlace: true)
      .call
  end

  def compress(path, quality:)
    ImageProcessing::Vips.source(path)
      .convert("jpeg")
      .saver(quality: quality, strip: true, interlace: true)
      .call
  end

  def good_enough?(result, original_size)
    result.size <= TARGET_SIZE && result.size < (original_size * 0.9)
  end

  def vips_dimensions(source)
    path = source.is_a?(String) ? source : source.path
    require "ruby-vips" unless defined?(::Vips)
    img = ::Vips::Image.new_from_file(path)
    [img.width, img.height]
  end
end
