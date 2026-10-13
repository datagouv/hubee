# frozen_string_literal: true

require "rails_helper"

# Couvre le câblage des logs : que le request_id et l'IP de l'appelant ressortent comme
# tags nommés sur la ligne de fin de requête. La forme `request_id="…"` est propre à logfmt
# (:json sérialiserait `"request_id":"…"`, :color tout autrement) : l'assertion garde
# donc aussi le format, sans réimplémenter la sérialisation de la gem.
#
# Lit log/test.log, c'est-à-dire l'appender que l'application a configuré — et non un
# appender posé par la spec, qui ne testerait que lui-même.
#
# Que production.rb déclare logfmt n'est pas couvert : il faudrait booter l'environnement
# de production dans un sous-process. Faisable désormais, non fait — relecture humaine.
RSpec.describe "Request logging", type: :request do
  # SemanticLogger écrit via un thread d'appender : sans flush, une ligne peut être encore en
  # file d'attente. Flusher avant de relever la position écarte les lignes des specs précédentes.
  def lines_logged_during
    log = Rails.root.join("log/test.log")
    SemanticLogger.flush
    offset = log.size
    yield
    SemanticLogger.flush
    log.read(nil, offset).lines
  end

  # Ce que la production écrit de la dernière requête : elle ne journalise pas en `debug`.
  def lines_of_the_response(lines)
    lines.grep(/request_id="#{response.headers["X-Request-Id"]}"/).grep_v(/level="debug"/)
  end

  it "tags the completed request line with the request id and the caller ip" do
    # Route applicative volontaire : la prod silence /up (silence_healthcheck_path).
    lines = lines_logged_during { get "/" }

    expect(response).to have_http_status(:success)
    expect(lines_of_the_response(lines).grep(/message="Completed/).first).to include(%(level="info"),
      %(request_id="#{response.headers["X-Request-Id"]}"), %(ip_address="127.0.0.1"))
  end

  # Le client forge Client-IP et le début de X-Forwarded-For ; le proxy ajoute 203.0.113.1.
  it "tags the address the proxy appended, whatever the client forged" do
    # Au niveau de la production : la ligne `Started`, en debug, lit aussi l'IP.
    lines = lines_logged_during do
      SemanticLogger.silence(:info) do
        get "/up", headers: {"Client-IP" => "198.51.100.1", "X-Forwarded-For" => "192.0.2.9, 203.0.113.1"}
      end
    end

    completed = lines_of_the_response(lines).grep(/message="Completed/).first
    expect(response).to have_http_status(:success)
    expect(completed).to include(%(message="Completed #show"), %(ip_address="203.0.113.1"))
  end

  # Les champs d'une décision d'accès sont des champs de la ligne, pas une chaîne échappée dans
  # le message : un filtre sur `outcome=` ou `ip_address=` les voit. Le request_id, porté par le
  # contexte de l'événement et par le tag nommé, ne sort qu'une fois ; l'IP de même.
  it "writes an access decision with its fields at the first level of the line" do
    lines = lines_logged_during { sign_in_via_proconnect(agent: create(:agent, provider_sub: "sub-logged")) }

    decision = lines.grep(/message="Décision d'accès"/).first
    expect(decision).to include(%(event="Portail::Auth::Decision"), %(outcome="granted"),
      %(ip_address="127.0.0.1"))
    expect(decision.scan("request_id=").size).to eq(1)
    expect(decision.scan("ip_address=").size).to eq(1)
  end

  it "carries the redirect and the halting filter on the completed line, the only one left" do
    lines = lines_logged_during { get "/teledossiers" }

    expect(response).to redirect_to(root_path)
    expect(lines_of_the_response(lines)).to contain_exactly(a_string_including(
      %(message="Completed #index"), "status=302", %(location="http://www.example.com/"),
      %(halted_callback="require_authentication")
    ))
  end

  it "masks the parameters of a redirect location, as Rails did" do
    sign_in_via_proconnect(agent: create(:agent))
    expect(Portail::ProConnect::Client).to receive(:logout_url)
      .and_return("https://proconnect.test/session/end?id_token_hint=jeton-d-identite")

    events = capture_semantic_logger_events { delete "/logout" }

    expect(events).to include(be_a_semantic_logger_event(message: "Completed #destroy",
      payload_includes: {location: "https://proconnect.test/session/end?id_token_hint=[FILTERED]"}))
  end

  it "logs an unknown route as a single completed line with the requested path, method and error" do
    # En test, Rails rend sa page de débogage ; la production rend la page d'erreur.
    env_config = Rails.application.env_config
    detailed = env_config["action_dispatch.show_detailed_exceptions"]
    lines = lines_logged_during do
      env_config["action_dispatch.show_detailed_exceptions"] = false
      post "/inconnue?origine=spec"
    ensure
      env_config["action_dispatch.show_detailed_exceptions"] = detailed
    end

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Page introuvable")
    expect(lines_of_the_response(lines)).to contain_exactly(a_string_including(
      %(message="Completed #not_found"), "status=404", %(path="/inconnue"), %(method="POST"),
      %(exception_class="ActionController::RoutingError"),
      %(exception_message="No route matches [POST] \\"/inconnue\\"")
    ))
  end

  # Toute autre exception garde sa ligne, pile comprise.
  it "drops only the lines carried by the completed line" do
    filter = Rails.application.config.x.log_filter
    entry = ->(metric: nil, exception: nil) do
      SemanticLogger::Log.new("Rails", :info).tap do |log|
        log.metric = metric
        log.exception = exception
      end
    end

    expect(filter.call(entry.call(metric: "rails.controller.process_action"))).to be(true)
    expect(filter.call(entry.call(exception: ActiveRecord::RecordNotFound.new))).to be(true)
    expect(filter.call(entry.call(exception: ActionController::BadRequest.new))).to be(true)
    expect(filter.call(entry.call(metric: "rails.controller.redirect_to"))).to be(false)
    expect(filter.call(entry.call(metric: "rails.controller.halted_callback"))).to be(false)
    expect(filter.call(entry.call(exception: ActionController::RoutingError.new("No route")))).to be(false)
  end
end
