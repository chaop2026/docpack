class PdfBuilder
  A4_WIDTH = 595
  A4_HEIGHT = 842

  def initialize(source_files)
    @source_files = source_files
  end

  def call
    @cleanup_paths = []

    page_paths = @source_files.map do |file|
      path = file.is_a?(String) ? file : file.path
      build_pdf_page(path)
    end

    combined = CombinePDF.new
    page_paths.each { |p| combined << CombinePDF.load(p) }

    output = Tempfile.new(["docpack", ".pdf"])
    combined.save(output.path)
    output.rewind
    output
  ensure
    @cleanup_paths&.each { |p| File.delete(p) if File.exist?(p) rescue nil }
  end

  private

  def build_pdf_page(image_path)
    resized = ImageProcessing::Vips
      .source(image_path)
      .convert("jpeg")
      .saver(quality: 75)
      .call
    @cleanup_paths << resized.path

    jpeg_data = File.binread(resized.path)
    require "ruby-vips" unless defined?(::Vips)
    img = ::Vips::Image.new_from_file(resized.path)
    img_w = img.width
    img_h = img.height

    scale = [A4_WIDTH.to_f / img_w, A4_HEIGHT.to_f / img_h].min
    fitted_w = (img_w * scale).to_i
    fitted_h = (img_h * scale).to_i
    x_offset = (A4_WIDTH - fitted_w) / 2
    y_offset = (A4_HEIGHT - fitted_h) / 2

    stream = "q #{fitted_w} 0 0 #{fitted_h} #{x_offset} #{y_offset} cm /Img Do Q"

    # Use a fixed path instead of Tempfile (which gets GC'd and unlinked)
    pdf_path = "/tmp/docpack_page_#{SecureRandom.hex(8)}.pdf"
    @cleanup_paths << pdf_path

    File.open(pdf_path, "wb") do |f|
      offsets = []
      f.write("%PDF-1.4\n")

      offsets << f.pos
      f.write("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

      offsets << f.pos
      f.write("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")

      offsets << f.pos
      f.write("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{A4_WIDTH} #{A4_HEIGHT}] /Contents 4 0 R /Resources << /XObject << /Img 5 0 R >> >> >>\nendobj\n")

      offsets << f.pos
      f.write("4 0 obj\n<< /Length #{stream.length} >>\nstream\n#{stream}\nendstream\nendobj\n")

      offsets << f.pos
      f.write("5 0 obj\n<< /Type /XObject /Subtype /Image /Width #{img_w} /Height #{img_h} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{jpeg_data.length} >>\nstream\n")
      f.write(jpeg_data)
      f.write("\nendstream\nendobj\n")

      xref_pos = f.pos
      f.write("xref\n0 6\n0000000000 65535 f \n")
      offsets.each { |o| f.write(format("%010d 00000 n \n", o)) }
      f.write("trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{xref_pos}\n%%EOF\n")
    end

    pdf_path
  end
end
