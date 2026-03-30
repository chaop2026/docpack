class ImageCompressor
  TARGET_SIZE = 2.megabytes

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
    # Try quality levels from high to low, find the best one that fits target
    best = nil

    scales = [1.0, 0.75, 0.5, 0.35, 0.25]
    qualities = [80, 65, 50, 40, 30, 20, 15, 10]

    # First pass: find the highest quality + largest scale that fits
    scales.each do |scale|
      qualities.each do |quality|
        w = (width * scale).to_i
        h = (height * scale).to_i

        pipeline = ImageProcessing::Vips.source(path)
        pipeline = pipeline.resize_to_limit(w, h) if scale < 1.0
        result = pipeline.convert("jpeg").saver(quality: quality, strip: true, interlace: true).call

        if result.size <= target_bytes
          # This fits — use it (it's the highest quality at this scale)
          best&.close!
          return result
        end

        result.close!
      end
    end

    # Nothing fit — use most aggressive
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
