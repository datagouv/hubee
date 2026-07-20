# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      include Interactor::Organizer

      organize VerifyIdToken, FindAgent
    end
  end
end
