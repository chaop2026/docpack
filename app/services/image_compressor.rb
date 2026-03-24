class ImageCompressor
  TARGET_SIZE = 2.megabytes
  QUALITY_STEPS = [80, 60].freeze

  def initialize(source)
    @source = source
  end

  def call
    image = ImageProcessing::Vips.source(@source)

    QUALITY_STEPS.each do |quality|
      result = image.convert("jpeg").saver(quality: quality).call
      return result if result.size <= TARGET_SIZE
    end

    # Final attempt: 50% resolution + quality 60
    pipeline = ImageProcessing::Vips.source(@source)
    width, height = vips_dimensions(@source)
    pipeline
      .resize_to_limit(width / 2, height / 2)
      .convert("jpeg")
      .saver(quality: 60)
      .call
  end

  private

  def vips_dimensions(source)
    img = Vips::Image.new_from_file(source.is_a?(String) ? source : source.path)
    [img.width, img.height]
  end
end
