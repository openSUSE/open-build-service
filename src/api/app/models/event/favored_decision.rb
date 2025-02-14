module Event
  class FavoredDecision < Decision
    self.description = 'Reported content favored'
    self.notification_explanation = 'Receive notifications for favored report decisions.'

    receiver_roles :offender, :reporter

    def subject
      decision = ::Decision.find(payload['id'])
      "Favored #{decision.reports.first.reportable&.class&.name || decision.reports.first.reportable_type} Report".squish
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(16777215)
#  undone_jobs :integer          default(0)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#
