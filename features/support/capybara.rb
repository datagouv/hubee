# frozen_string_literal: true

# Chrome signale un nœud d'un document déjà remplacé, en pleine redirection, par une erreur
# générique que Capybara ne rejoue pas : rejouée ici comme un élément périmé, elle attend la page.
class PortailSeleniumDriver < Capybara::Selenium::Driver
  def invalid_element_errors = super + [Selenium::WebDriver::Error::UnknownError]
end

# rack_test par défaut (rapide, sans navigateur) ; Selenium ne sert qu'aux scénarios
# @javascript — capybara/cucumber bascule dessus via le tag.
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1280,800")

  # Selenium Manager n'a pas de binaire Linux ARM : quand le chromedriver système existe
  # (VM de dev), il prend le relais ; ailleurs, résolution automatique.
  service = nil
  if File.exist?("/usr/bin/chromedriver")
    options.binary = "/usr/bin/chromium" if File.exist?("/usr/bin/chromium")
    service = Selenium::WebDriver::Service.chrome(path: "/usr/bin/chromedriver")
  end

  PortailSeleniumDriver.new(app, browser: :chrome, options:, service:)
end

Capybara.javascript_driver = :selenium_chrome_headless
