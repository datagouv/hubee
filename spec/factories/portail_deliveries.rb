# frozen_string_literal: true

# Les modèles du portail. Les factories de la gem (`build_v2_*`) ne servent qu'à la frontière.
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
    total { 1 }
  end

  factory :portail_delivery_summary, class: "Portail::DeliverySummary" do
    skip_create
    initialize_with { new(**attributes) }

    transient { data_stream_code { "CERTDC" } }

    id { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
    number { "DGS-CERTDC-0000000000001-01" }
    state { "acknowledged" }
    data_stream { build(:portail_data_stream, code: data_stream_code) }
    transmitted_at { 2.hours.ago }
    updated_at { 1.hour.ago }
  end

  factory :portail_attachment, class: "Portail::Attachment" do
    skip_create
    initialize_with { new(**attributes) }

    id { "a1111111-1111-1111-1111-111111111111" }
    filename { "certificat.pdf" }
    content_type { "application/pdf" }
    byte_size { 1024 }
    kind { "VA_CertificatdeDeces" }
    state { "received" }
  end

  factory :portail_event, class: "Portail::Event" do
    skip_create
    initialize_with { new(**attributes) }

    id { "e1111111-1111-1111-1111-111111111111" }
    event_type { "delivery.state_changed" }
    created_at { 1.hour.ago }
    author { "George DUBOIS" }
    content { "Dossier pris en charge" }
    si_comment { nil }
    metadata { {from_state: "transmitted", to_state: "acknowledged"} }
    attachments { [] }
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
    attachments { [build(:portail_attachment)] }
    events { [build(:portail_event)] }
  end

  factory :portail_delivery_list, class: "Portail::DeliveryList" do
    skip_create
    initialize_with { new(**attributes) }

    deliveries { [] }
    pagination { build(:portail_pagination) }
    # Emprunté à la page vide plutôt que recopié : les états n'ont qu'une source.
    counts_by_state {
      Portail::HubAPI::Deliveries.empty_list(per_page: Portail::DeliveriesQuery::PER_PAGE)
        .counts_by_state
    }
  end
end
