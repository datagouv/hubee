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
# Que production.rb déclare logfmt n'est pas couvert ici : la production ne boote pas
# (initializer strong_migrations, ticket séparé). Un spec en sous-process deviendra
# possible une fois ce bug corrigé ; d'ici là, relecture humaine.
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
end
