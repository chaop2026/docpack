class SocialResizer
  PRESETS = {
    "instagram_square" => { width: 1080, height: 1080, label: "Instagram 1:1" },
    "instagram_portrait" => { width: 1080, height: 1350, label: "Instagram 4:5" },
    "facebook_feed" => { width: 1200, height: 630, label: "Facebook Feed 1.91:1" },
    "facebook_story" => { width: 1080, height: 1920, label: "Facebook Story 9:16" }
  }.freeze

  TARGET_SIZE = 2.megabytes

  def initialize(source, preset_key)
    @source = source
    @preset = PRESETS.fetch(preset_key)
  end

  def call
    width = @preset[:width]
    height = @preset[:height]

    result = ImageProcessing::Vips
      .source(@source)
      .resize_to_fill(width, height)
      .convert("jpeg")
      .saver(quality: 85)
      .call

    return result if result.size <= TARGET_SIZE

    ImageProcessing::Vips
      .source(result.path)
      .convert("jpeg")
      .saver(quality: 60)
      .call
  end

  def self.preset_options
    PRESETS.map { |key, val| [val[:label], key] }
  end
end
