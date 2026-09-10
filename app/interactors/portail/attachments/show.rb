# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      include Interactor::Organizer

      organize Show::FetchContent
    end
  end
end
