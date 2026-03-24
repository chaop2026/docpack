class ImageCompressor
  TARGET_SIZE = 2.megabytes

  def initialize(source)
    @source = source
  end

  def call
    path = @source.is_a?(String) ? @source : @source.path
    original_size = File.size(path)

    # Step 1: quality 80, strip metadata, progressive
    result = compress(path, quality: 80)
    return result if good_enough?(result, original_size)

    # Step 2: quality 65
    result = compress(path, quality: 65)
    return result if good_enough?(result, original_size)

    # Step 3: quality 50
    result = compress(path, quality: 50)
    return result if good_enough?(result, original_size)

    # Step 4: half resolution + quality 50
    width, height = vips_dimensions(path)
    ImageProcessing::Vips
      .source(path)
      .resize_to_limit(width / 2, height / 2)
      .convert("jpeg")
      .saver(quality: 50, strip: true, interlace: true)
      .call
  end

  private

  def compress(path, quality:)
    ImageProcessing::Vips
      .source(path)
      .convert("jpeg")
      .saver(quality: quality, strip: true, interlace: true)
      .call
  end

  def good_enough?(result, original_size)
    result.size <= TARGET_SIZE && result.size < (original_size * 0.9)
  end

  def vips_dimensions(source)
    img = Vips::Image.new_from_file(source.is_a?(String) ? source : source.path)
    [img.width, img.height]
  end
end
