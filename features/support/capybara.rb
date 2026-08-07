# frozen_string_literal: true

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

  Capybara::Selenium::Driver.new(app, browser: :chrome, options:, service:)
end

Capybara.javascript_driver = :selenium_chrome_headless
