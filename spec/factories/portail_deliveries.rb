# frozen_string_literal: true

# Les modèles du portail. Les factories de la gem (`build_v2_*`) ne servent qu'à la frontière.
FactoryBot.define do
  factory :portail_applicant, class: "Portail::Delivery::Applicant" do
    skip_create
    initialize_with { new(**attributes) }

    first_name { "George" }
    last_name { "DUBOIS" }
  end

  # Par défaut l'organisation de l'agent des request specs : ce que l'amont sert doit lui
  # appartenir. `membership:` prend l'organisation d'un rattachement donné.
  factory :portail_recipient, class: "Portail::Delivery::Recipient" do
    skip_create
    initialize_with { new(**attributes) }

    transient { membership { nil } }

    siret { membership ? membership.organization_link.siret : ProConnectTestHelper::TEST_SIRET }
    insee_code { membership ? membership.organization_link.insee_code : ProConnectTestHelper::TEST_INSEE_CODE }

    trait :of_another_organisation do
      siret { "13002526500013" }
      insee_code { "75056" }
    end
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

  factory :portail_delivery_summary, class: "Portail::Delivery::Summary" do
    skip_create
    initialize_with { new(**attributes) }

    transient do
      data_stream_code { "CERTDC" }
      membership { nil }
    end

    id { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
    number { "DGS-CERTDC-0000000000001-01" }
    state { "acknowledged" }
    data_stream { build(:portail_data_stream, code: data_stream_code) }
    recipient { build(:portail_recipient, membership: membership) }
    transmitted_at { 2.hours.ago }
    updated_at { 1.hour.ago }

    trait :of_another_organisation do
      recipient { build(:portail_recipient, :of_another_organisation) }
    end
  end

  factory :portail_attachment, class: "Portail::Delivery::Attachment" do
    skip_create
    initialize_with { new(**attributes) }

    id { "a1111111-1111-1111-1111-111111111111" }
    filename { "certificat.pdf" }
    content_type { "application/pdf" }
    byte_size { 1024 }
    kind { "VA_CertificatdeDeces" }
    state { "received" }
  end

  factory :portail_event, class: "Portail::Delivery::Event" do
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

    transient do
      data_stream_code { "CERTDC" }
      membership { nil }
    end

    id { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
    number { "DGS-CERTDC-0000000000001-01" }
    state { "acknowledged" }
    data_stream { build(:portail_data_stream, code: data_stream_code) }
    recipient { build(:portail_recipient, membership: membership) }
    transmitted_at { 2.hours.ago }
    updated_at { 1.hour.ago }
    applicant { build(:portail_applicant) }
    attachments { [build(:portail_attachment)] }
    events { [build(:portail_event)] }

    trait :of_another_organisation do
      recipient { build(:portail_recipient, :of_another_organisation) }
    end
  end

  factory :portail_delivery_list, class: "Portail::Delivery::List" do
    skip_create
    initialize_with { new(**attributes) }

    deliveries { [] }
    pagination { build(:portail_pagination) }
    # Les états de l'amont, dans son ordre.
    counts_by_state {
      %w[transmitted acknowledged in_progress awaiting_documents done refused closed integration_error]
        .index_with(0)
    }
  end
end
