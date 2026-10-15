# frozen_string_literal: true

# Le logfmt de semantic_logger écrase `name` et `message` de la ligne par ceux de l'exception :
# « ProConnect indisponible » disparaissait. Les champs de l'exception gardent ici leur nom.
class LogfmtFormatter < SemanticLogger::Formatters::Logfmt
  private

  def handle_exception
    return unless @raw.key?(:exception)

    exception = @raw[:exception]
    @parsed[:tag] = "exception"
    @parsed.merge!(exception_class: exception[:name], exception_message: exception[:message],
      **exception.except(:name, :message))
  end
end
