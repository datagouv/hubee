# frozen_string_literal: true

# Une liste vide est un choix légitime, mais elle doit être explicite : une variable oubliée
# produirait le même comportement — plus personne n'est soumis au second facteur au titre
# d'un processus — sans que rien ne le dise.
#
# SECRET_KEY_BASE_DUMMY marque la précompilation des assets, qui démarre l'application sans
# aucun secret : la variable est requise pour servir, pas pour construire l'image.
unless ENV.key?("SENSITIVE_PROCESS_CODES") || ENV["SECRET_KEY_BASE_DUMMY"].present?
  raise "SENSITIVE_PROCESS_CODES est requise — voir .env.example"
end
