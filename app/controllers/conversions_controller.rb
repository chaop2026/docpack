class ConversionsController < ApplicationController
  MAX_FILE_SIZE = 10.megabytes
  MAX_FILES = 20
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp image/heic].freeze

  def create
    files = Array(params[:files]).reject(&:blank?)

    if files.empty?
      redirect_back fallback_location: root_path, alert: t("upload.no_files")
      return
    end

    if files.size > MAX_FILES
      redirect_back fallback_location: root_path, alert: t("upload.too_many", max: MAX_FILES)
      return
    end

    oversized = files.select { |f| f.size > MAX_FILE_SIZE }
    if oversized.any?
      redirect_back fallback_location: root_path, alert: t("upload.too_large", max: "10MB")
      return
    end

    invalid = files.reject { |f| ALLOWED_TYPES.include?(f.content_type) }
    if invalid.any?
      redirect_back fallback_location: root_path, alert: t("upload.invalid_type")
      return
    end

    @conversion = Conversion.new(
      conversion_type: params[:conversion_type],
      status: "pending"
    )

    unless @conversion.save
      redirect_back fallback_location: root_path, alert: "Invalid conversion type."
      return
    end

    @conversion.source_files.attach(files)
    @conversion.update(original_size: calculate_total_size(@conversion.source_files))

    process_conversion(@conversion)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversion }
    end
  end

  def show
    @conversion = Conversion.find(params[:id])
  end

  def download
    @conversion = Conversion.find(params[:id])

    unless @conversion.result_file.attached?
      redirect_to @conversion, alert: "Result file not available."
      return
    end

    send_data @conversion.result_file.download,
              filename: @conversion.result_file.filename.to_s,
              content_type: @conversion.result_file.content_type,
              disposition: "attachment"
  end

  private

  def calculate_total_size(files)
    files.sum { |f| f.blob.byte_size }
  end

  def process_conversion(conversion)
    case conversion.conversion_type
    when "compress"
      process_compress(conversion)
    when "pdf"
      process_pdf(conversion)
    when "social"
      process_social(conversion)
    end
  rescue => e
    conversion.update(status: "failed")
    Rails.logger.error("Conversion ##{conversion.id} failed: #{e.message}")
  end

  def process_compress(conversion)
    target_percent = params[:target_percent].present? ? params[:target_percent].to_i : nil
    results = conversion.source_files.map do |file|
      file.open do |tempfile|
        ImageCompressor.new(tempfile.path, target_percent: target_percent).call
      end
    end

    if results.size == 1
      conversion.result_file.attach(
        io: File.open(results.first.path),
        filename: "compressed.jpg",
        content_type: "image/jpeg"
      )
    else
      zip_file = create_zip(results)
      conversion.result_file.attach(
        io: File.open(zip_file.path),
        filename: "compressed_images.zip",
        content_type: "application/zip"
      )
      zip_file.close!
    end

    conversion.update(status: "done", result_size: conversion.result_file.blob.byte_size)
    results.each { |r| r.close! if r.respond_to?(:close!) }
  end

  def process_pdf(conversion)
    tempfiles = []
    conversion.source_files.each do |file|
      tf = Tempfile.new(["pdf_src", File.extname(file.filename.to_s)])
      tf.binmode
      file.download { |chunk| tf.write(chunk) }
      tf.rewind
      tempfiles << tf
    end

    result = PdfBuilder.new(tempfiles).call

    conversion.result_file.attach(
      io: File.open(result.path),
      filename: "docpack.pdf",
      content_type: "application/pdf"
    )
    conversion.update(status: "done", result_size: conversion.result_file.blob.byte_size)
  ensure
    tempfiles&.each(&:close!)
    result&.close! if result.respond_to?(:close!)
  end

  def process_social(conversion)
    preset = params[:preset] || "instagram_square"
    results = conversion.source_files.map do |file|
      file.open do |tempfile|
        SocialResizer.new(tempfile.path, preset).call
      end
    end

    if results.size == 1
      conversion.result_file.attach(
        io: File.open(results.first.path),
        filename: "social_#{preset}.jpg",
        content_type: "image/jpeg"
      )
    else
      zip_file = create_zip(results)
      conversion.result_file.attach(
        io: File.open(zip_file.path),
        filename: "social_#{preset}.zip",
        content_type: "application/zip"
      )
      zip_file.close!
    end

    conversion.update(status: "done", result_size: conversion.result_file.blob.byte_size)
    results.each { |r| r.close! if r.respond_to?(:close!) }
  end

  def create_zip(files)
    require "zip" if defined?(Zip)

    zip_tempfile = Tempfile.new(["docpack", ".zip"])
    Zip::OutputStream.open(zip_tempfile.path) do |zos|
      files.each_with_index do |file, i|
        zos.put_next_entry("image_#{i + 1}.jpg")
        zos.write(File.binread(file.path))
      end
    end
    zip_tempfile
  end
end
