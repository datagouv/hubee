# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# Ajouts propres à HubEE :
#
#   code          le code d'autorisation OAuth, échangeable contre des jetons. Il
#                 transite dans l'URL de callback ProConnect et se retrouvait en clair
#                 dans les journaux.
#   provider_sub  l'identifiant pseudonyme de l'agent chez ProConnect : donnée
#                 personnelle, stable dans le temps.
#   message       le message joint à un changement d'état, saisi librement : il peut
#                 nommer un usager.
#   piece         la pièce jointe à un changement d'état, dont le nom de fichier peut
#                 nommer un usager.
#   nonce         l'aléa anti-rejeu de la demande d'autorisation ProConnect.
#   login_hint    l'adresse de l'agent, suggérée à ProConnect lors d'une élévation.
#
# La correspondance est partielle : `code` masquerait aussi un futur `postal_code`. Ces
# filtres s'appliquent aussi aux paramètres d'une URL de redirection journalisée.
Rails.application.config.filter_parameters += [:code, :provider_sub, :message, :piece, :nonce, :login_hint]
