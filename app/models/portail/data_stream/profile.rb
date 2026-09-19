# frozen_string_literal: true

module Portail
  # Ce que le portail sait d'une démarche. ⚠️ Lire une permission ne suffit pas : c'est au portail
  # de la faire respecter. Les paramètres servis en plus n'entrent qu'avec leur consommateur.
  DataStream::Profile = Data.define(:code, :name, :awaiting_documents) do
    # « Non renseigné » n'est pas une autorisation : une démarche jamais paramétrée ne doit pas se
    # prendre pour une démarche permissive.
    def awaiting_documents_allowed? = awaiting_documents == "allowed"
  end
end
