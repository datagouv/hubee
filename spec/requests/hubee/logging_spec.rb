# frozen_string_literal: true

require "rails_helper"

# Couvre le câblage des logs : que le request_id posé par Rails ressorte comme tag
# nommé sur la ligne de fin de requête. La forme `request_id="…"` est propre à logfmt
# (:json sérialiserait `"request_id":"…"`, :color tout autrement) : l'assertion garde
# donc aussi le format, sans réimplémenter la sérialisation de la gem.
#
# Lit log/test.log, c'est-à-dire l'appender que l'application a configuré — et non un
# appender posé par la spec, qui ne testerait que lui-même.
#
# Que production.rb déclare logfmt n'est pas couvert : il faudrait booter l'environnement
# de production dans un sous-process. Faisable désormais, non fait — relecture humaine.
RSpec.describe "Request logging", type: :request do
  it "tags the completed request line with the request id carried by the response" do
    log = Rails.root.join("log/test.log")
    # SemanticLogger écrit via un thread d'appender séparé : sans flush, la ligne de la
    # requête peut être encore en file d'attente et pas encore présente dans le fichier.
    # Flusher avant de relever l'offset écarte aussi les lignes des specs précédentes.
    SemanticLogger.flush
    offset = log.size

    # Route applicative volontaire : la prod silence /up (silence_healthcheck_path),
    # sa ligne de log n'y existe donc pas.
    get "/"

    SemanticLogger.flush
    # Seule la ligne de fin de requête est en `info`, donc émise en prod (log_level info) ;
    # les lignes `debug` qui l'entourent ici n'y apparaissent pas.
    completed = log.read(nil, offset).lines.grep(/message="Completed/).first

    expect(response).to have_http_status(:success)
    expect(completed).to be_present
    expect(completed).to include(%(level="info"))
    expect(completed).to include(%(request_id="#{response.headers["X-Request-Id"]}"))
  end

  # Les champs d'une décision d'accès sont des champs de la ligne, pas une chaîne échappée dans
  # le message : un filtre sur `outcome=` ou `ip_address=` les voit. Le request_id, porté par le
  # contexte de l'événement et par le tag nommé, ne sort qu'une fois.
  it "writes an access decision with its fields at the first level of the line" do
    log = Rails.root.join("log/test.log")
    SemanticLogger.flush
    offset = log.size

    sign_in_via_proconnect(agent: create(:agent, provider_sub: "sub-logged"))

    SemanticLogger.flush
    decision = log.read(nil, offset).lines.grep(/message="Décision d'accès"/).first

    expect(decision).to be_present
    expect(decision).to include(%(event="Portail::Auth::Decision"), %(outcome="granted"),
      %(ip_address="127.0.0.1"))
    expect(decision.scan("request_id=").size).to eq(1)
  end
end
