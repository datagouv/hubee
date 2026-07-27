# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail authentication", type: :system do
  before { driven_by(:rack_test) }

  it "shows the official ProConnect button and its mandatory info link to anonymous visitors" do
    visit root_path

    expect(page).to have_button("S'identifier avec ProConnect")
    expect(page).to have_css("button.proconnect-button")
    expect(page).to have_link("Qu'est-ce que ProConnect ?", href: "https://www.proconnect.gouv.fr/")
    expect(page).to have_no_button("Se déconnecter")
  end
end
