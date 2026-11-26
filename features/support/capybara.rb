# frozen_string_literal: true

# Chrome signale un nœud d'un document déjà remplacé, en pleine redirection, par une erreur
# générique que Capybara ne rejoue pas : rejouée ici comme un élément périmé, elle attend la page.
class PortailSeleniumDriver < Capybara::Selenium::Driver
  # Chrome 158 refuse l'origine « * » du dernier appel de ChromeDriver#reset! (teamcapybara/capybara#2865) :
  # cookies vidés pour tout le navigateur, stockage pour chaque origine visitée. Étendu après la
  # spécialisation Chrome, elle-même étendue sur l'instance, pour la surcharger.
  module ResetWithoutWildcardOrigin
    private

    def execute_cdp(cmd, params = {})
      return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

      super("Network.clearBrowserCookies")
      return unless params[:storageTypes].include?("local_storage")

      visited_origins.each { |origin| super(cmd, origin:, storageTypes: "local_storage") }
    end

    def visited_origins
      execute_cdp("Page.getNavigationHistory")["entries"].map { URI(it["url"]) }.grep(URI::HTTP).map(&:origin).uniq
    end
  end

  def invalid_element_errors = super + [Selenium::WebDriver::Error::UnknownError]

  private

  def specialize_driver
    super
    extend ResetWithoutWildcardOrigin
  end
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
