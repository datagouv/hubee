# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery::Reply do
  it "keeps the name, the size and the bytes of the file" do
    reply = portail_reply

    expect(reply.filename).to eq("decision.pdf")
    expect(reply.byte_size).to eq(PortailUploads::PDF_BYTES.bytesize)
    expect(reply.bytes).to eq(PortailUploads::PDF_BYTES)
  end

  # Le navigateur annonce ce qu'il veut : seul le contenu fait foi.
  it "reads the type from the content, not from what the browser announces" do
    expect(portail_reply(filename: "decision.png", content_type: "image/png").content_type)
      .to eq("application/pdf")
  end

  it "keeps only the last segment of a name carrying a path" do
    expect(portail_reply(filename: "..\\dossier/../decision.pdf").filename).to eq("decision.pdf")
  end

  it "keeps no name when the name holds nothing but separators" do
    expect(portail_reply(filename: "/").filename).to eq("")
  end

  it "gives the bytes in full even after the type was read" do
    reply = portail_reply
    reply.content_type

    expect(reply.bytes).to eq(PortailUploads::PDF_BYTES)
  end

  it "sees no file in an absent or forged parameter" do
    expect(described_class.of(nil)).to be_nil
    expect(described_class.of("decision.pdf")).to be_nil
  end
end
