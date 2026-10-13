# frozen_string_literal: true

# Ce que Rails écrit à part pendant une action va sur sa ligne de fin de requête, pour tous
# les contrôleurs, y compris ceux des gems (Doorkeeper, /up) : config.x.log_filter retire les
# lignes à part pour tous.
module RequestLog
  private

  def halted_callback_hook(filter, name)
    @halted_callback = filter
    super
  end

  # `filtered_location`, comme la ligne que Rails écrivait : filter_parameters s'applique aux
  # paramètres de l'URL.
  def append_info_to_payload(payload)
    super
    payload[:location] = response.filtered_location if response.redirect?
    payload[:halted_callback] = @halted_callback.to_s if @halted_callback
  end
end

ActiveSupport.on_load(:action_controller) { include RequestLog }
