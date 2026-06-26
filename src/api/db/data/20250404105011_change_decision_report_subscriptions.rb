# frozen_string_literal: true

class ChangeDecisionReportSubscriptions < ActiveRecord::Migration[7.0]
  def up
    report_subscriptions = EventSubscription.where(eventtype: %w[Event::ReportForComment Event::ReportForPackage Event::ReportForProject Event::ReportForRequest Event::ReportForUser])
    process(report_subscriptions, 'Event::Report')

    decision_subscriptions = EventSubscription.where(eventtype: %w[Event::ClearedDecision Event::FavoredDecision])
    process(decision_subscriptions, 'Event::Decision')
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def process(subscriptions, type)
    scoped_subscriptions = subscriptions.map { |s| s.attributes.slice('enabled', 'user_id', 'group_id', 'receiver_role', 'channel') }
    grouped_subscriptions = scoped_subscriptions.group_by { |s| [s['user_id'], s['group_id'], s['receiver_role'], s['channel']] }

    grouped_subscriptions.each do |_, same_subscriptions|
      subscription = same_subscriptions.max_by { |i| same_subscriptions.count { |s| s['enabled'] == i['enabled'] } }
      EventSubscription.create(subscription.merge({ eventtype: type }))
    end
    subscriptions.destroy_all
  end
end
