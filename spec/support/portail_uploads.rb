# frozen_string_literal: true

# Un PDF minimal : Marcel le reconnaît à sa signature, quel que soit le nom ou le type annoncé.
module PortailUploads
  PDF_BYTES = "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n".b

  def pdf_upload(filename: "decision.pdf", content_type: "application/pdf", bytes: PDF_BYTES)
    Rack::Test::UploadedFile.new(StringIO.new(bytes), content_type, true, original_filename: filename)
  end

  # La réponse que le contrôleur construit, pour les specs qui s'en passent.
  def portail_reply(**)
    file = pdf_upload(**)
    Portail::Delivery::Reply.of(ActionDispatch::Http::UploadedFile.new(
      tempfile: file.tempfile, filename: file.original_filename, type: file.content_type
    ))
  end
end

RSpec.configure do |config|
  config.include PortailUploads
end
