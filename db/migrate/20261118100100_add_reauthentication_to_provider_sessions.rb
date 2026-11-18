# frozen_string_literal: true

class AddReauthenticationToProviderSessions < ActiveRecord::Migration[8.1]
  def change
    # La preuve d'une réauthentification, attachée à la session qu'elle renforce : elle meurt avec
    # elle. Une seule à la fois, une nouvelle remplace la précédente.
    add_column :provider_sessions, :reauthenticated_at, :datetime
    add_column :provider_sessions, :reauthenticated_for, :string
    add_column :provider_sessions, :reauthentication_consumed_at, :datetime
  end
end
