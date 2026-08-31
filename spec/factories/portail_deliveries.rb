# frozen_string_literal: true

# Les modèles du portail, ceux que voient les contrôleurs, les vues et les policies. Les
# factories de la gem (`build_v2_*`) ne servent plus qu'à la frontière — le spec de
# Portail::HubAPI et l'intégration Cucumber.
FactoryBot.define do
  factory :portail_applicant, class: "Portail::Applicant" do
    skip_create
    initialize_with { new(**attributes) }

    first_name { "George" }
    last_name { "DUBOIS" }
  end

  factory :portail_data_stream, class: "Portail::DataStream" do
    skip_create
    initialize_with { new(**attributes) }

    code { "CERTDC" }
  end

  factory :portail_pagination, class: "Portail::Pagination" do
    skip_create
    initialize_with { new(**attributes) }

    current_page { 1 }
    total_pages { 1 }
  end

  factory :portail_delivery_summary, class: "Portail::DeliverySummary" do
    skip_create
    initialize_with { new(**attributes) }

    # Transient : les exemples désignent un flux par son code, la factory construit l'objet.
    transient { data_stream_code { "CERTDC" } }

    id { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
    number { "DGS-CERTDC-0000000000001-01" }
    state { "acknowledged" }
    data_stream { build(:portail_data_stream, code: data_stream_code) }
    transmitted_at { 2.hours.ago }
    updated_at { 1.hour.ago }
  end

  factory :portail_delivery, class: "Portail::Delivery" do
    skip_create
    initialize_with { new(**attributes) }

    transient { data_stream_code { "CERTDC" } }

    id { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
    number { "DGS-CERTDC-0000000000001-01" }
    state { "acknowledged" }
    data_stream { build(:portail_data_stream, code: data_stream_code) }
    transmitted_at { 2.hours.ago }
    updated_at { 1.hour.ago }
    applicant { build(:portail_applicant) }
  end

  factory :portail_delivery_list, class: "Portail::DeliveryList" do
    skip_create
    initialize_with { new(**attributes) }

    deliveries { [] }
    pagination { build(:portail_pagination) }
    # Emprunté à la page vide plutôt que recopié : les états et leur ordre n'ont qu'une seule
    # source, et une liste de test ne doit pas pouvoir en inventer une seconde.
    counts_by_state { Portail::HubAPI::Deliveries.empty_list(per_page: 25).counts_by_state }
  end
end
