# frozen_string_literal: true

module Portail
  class BaseController < ApplicationController
    include Portail::Authentication

    layout "portail"
  end
end
