# frozen_string_literal: true

# Un agent connecté par ProConnect, rattaché à l'organisation simulée avec son rôle et ses
# habilitations.
module PortailSignInHelper
  # Le cas standard du portail : un membre habilité sur le flux des télédossiers servis.
  def sign_in_member(data_stream_codes: ["CERTDC"])
    agent = create(:agent, provider_sub: "sub-membre")
    sign_in_via_proconnect(agent: agent)
    membership = Membership.find_by!(agent: agent)
    data_stream_codes.each { |code| create(:data_stream_access, membership: membership, data_stream_code: code) }
    agent
  end

  def sign_in_local_administrator(data_stream_codes: [])
    agent = sign_in_member(data_stream_codes: data_stream_codes)
    Membership.find_by!(agent: agent).update!(role: "local_administrator")
    agent
  end
end

RSpec.configure do |config|
  config.include PortailSignInHelper, type: :request
end
