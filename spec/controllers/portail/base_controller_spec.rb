# frozen_string_literal: true

require "rails_helper"

# Fermé par défaut : un contrôleur du portail qui n'autorise rien est refusé, sauf déclaration
# explicite. Un contrôleur anonyme, pour ne dépendre d'aucune page réelle.
RSpec.describe Portail::BaseController, type: :controller do
  controller do
    allow_unauthenticated_access

    def index = head(:ok)

    def show = head(:ok)
  end

  it "refuses a collection action that scoped no policy" do
    expect { get :index }.to raise_error(Pundit::PolicyScopingNotPerformedError)
  end

  it "refuses a member action that authorized nothing" do
    expect { get :show, params: {id: "1"} }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end
end
