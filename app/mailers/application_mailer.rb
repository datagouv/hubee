class ApplicationMailer < ActionMailer::Base
  layout "mailer"

  # Le bloc-marque du layout voyage avec le message : Outlook bloque par défaut les images distantes.
  before_action do
    %w[marianne-clair.png marianne-sombre.png].each do
      attachments.inline[it] = Rails.root.join("app/assets/images/courriels", it).binread
    end
  end
end
