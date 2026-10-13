# frozen_string_literal: true

# Ce que Rails écrit à part pendant une action va sur sa ligne de fin de requête, pour tous
# les contrôleurs, y compris ceux des gems (Doorkeeper, /up) : config.x.log_filter retire les
# lignes à part pour tous.
module RequestLog
  # Rails renvoie l'exception traitée, qui peut être la cause de celle levée.
  def rescue_with_handler(exception)
    @rescued_exception = super
  end

  private

  def halted_callback_hook(filter, name)
    @halted_callback = filter
    super
  end

  # Rails rejoue la requête vers la page d'erreur en GET : on reprend ce qui avait été demandé,
  # et l'exception qui y a répondu.
  def append_replayed_request(payload)
    exception = request.get_header("action_dispatch.exception")
    return unless exception

    payload[:path] = request.original_fullpath
    payload[:method] = request.get_header("action_dispatch.original_request_method")
    payload[:exception_class] = exception.class.name
    payload[:exception_message] = exception.message
  end

  # `filtered_location`, comme la ligne que Rails écrivait : filter_parameters s'applique aux
  # paramètres de l'URL.
  def append_info_to_payload(payload)
    super
    append_replayed_request(payload)
    payload[:location] = response.filtered_location if response.redirect?
    payload[:halted_callback] = @halted_callback.to_s if @halted_callback
    return unless @rescued_exception

    payload[:rescued_exception_class] = @rescued_exception.class.name
    payload[:rescued_exception_message] = @rescued_exception.message
    payload[:rescued_exception_backtrace] = @rescued_exception.backtrace&.first&.delete_prefix("#{Rails.root}/")
  end
end

ActiveSupport.on_load(:action_controller) { include RequestLog }
