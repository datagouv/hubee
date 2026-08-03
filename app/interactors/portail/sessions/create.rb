# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      include Interactor::Organizer

      organize VerifyIdToken, CheckAuthenticationLevel, FindAgent
    end
  end
end
