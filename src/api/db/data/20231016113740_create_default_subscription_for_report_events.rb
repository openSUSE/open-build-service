# frozen_string_literal: true

class CreateDefaultSubscriptionForReportEvents < ActiveRecord::Migration[7.0]
  def up
    EventSubscription.create!(eventtype: Event::ReportForProject.name, channel: :web, receiver_role: :moderator, enabled: true)
    EventSubscription.create!(eventtype: Event::ReportForPackage.name, channel: :web, receiver_role: :moderator, enabled: true)
    EventSubscription.create!(eventtype: Event::ReportForComment.name, channel: :web, receiver_role: :moderator, enabled: true)
    EventSubscription.create!(eventtype: Event::ReportForUser.name, channel: :web, receiver_role: :moderator, enabled: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
