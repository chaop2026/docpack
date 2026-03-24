class PdfBuilder
  TARGET_SIZE = 2.megabytes
  A4_WIDTH = 595
  A4_HEIGHT = 842

  def initialize(source_files)
    @source_files = source_files
  end

  def call
    temp_pdfs = []
    compressed = []

    @source_files.each do |file|
      path = file.is_a?(String) ? file : file.path
      comp = ImageCompressor.new(path).call
      compressed << comp
      temp_pdfs << image_to_pdf_page(comp.path)
    end

    combined = CombinePDF.new
    temp_pdfs.each { |pdf_path| combined << CombinePDF.load(pdf_path) }

    output = Tempfile.new(["docpack", ".pdf"])
    combined.save(output.path)
    output.rewind
    output
  ensure
    compressed&.each { |f| f.close! if f.respond_to?(:close!) }
    temp_pdfs&.each { |p| File.delete(p) if p && File.exist?(p) }
  end

  private

  def image_to_pdf_page(image_path)
    img = Vips::Image.new_from_file(image_path)

    scale_w = A4_WIDTH.to_f / img.width
    scale_h = A4_HEIGHT.to_f / img.height
    scale = [scale_w, scale_h].min

    fitted_w = (img.width * scale).to_i
    fitted_h = (img.height * scale).to_i

    resized = ImageProcessing::Vips
      .source(image_path)
      .resize_to_limit(fitted_w, fitted_h)
      .convert("jpeg")
      .saver(quality: 75)
      .call

    jpeg_data = File.binread(resized.path)
    resized_img = Vips::Image.new_from_file(resized.path)
    img_w = resized_img.width
    img_h = resized_img.height

    x_offset = (A4_WIDTH - fitted_w) / 2
    y_offset = (A4_HEIGHT - fitted_h) / 2
    stream_content = "q #{fitted_w} 0 0 #{fitted_h} #{x_offset} #{y_offset} cm /Img Do Q"

    pdf_file = Tempfile.new(["page", ".pdf"])
    write_pdf_with_image(pdf_file.path, jpeg_data, img_w, img_h, stream_content)
    pdf_file.path
  end

  def write_pdf_with_image(path, jpeg_data, img_w, img_h, stream_content)
    File.open(path, "wb") do |f|
      offsets = []

      f.write("%PDF-1.4\n")

      offsets << f.pos
      f.write("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

      offsets << f.pos
      f.write("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")

      offsets << f.pos
      f.write("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{A4_WIDTH} #{A4_HEIGHT}] /Contents 4 0 R /Resources << /XObject << /Img 5 0 R >> >> >>\nendobj\n")

      offsets << f.pos
      f.write("4 0 obj\n<< /Length #{stream_content.length} >>\nstream\n#{stream_content}\nendstream\nendobj\n")

      offsets << f.pos
      f.write("5 0 obj\n<< /Type /XObject /Subtype /Image /Width #{img_w} /Height #{img_h} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{jpeg_data.length} >>\nstream\n")
      f.write(jpeg_data)
      f.write("\nendstream\nendobj\n")

      xref_pos = f.pos
      f.write("xref\n0 6\n0000000000 65535 f \n")
      offsets.each { |o| f.write(format("%010d 00000 n \n", o)) }
      f.write("trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{xref_pos}\n%%EOF\n")
    end
  end
end
