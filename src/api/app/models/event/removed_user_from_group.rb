module Event
  class RemovedUserFromGroup < Group
    self.description = 'Removed member from group'
    self.notification_explanation = 'Receive notifications when you are removed from a group.'

    def subject
      return "You were removed from the group '#{payload['group']}'" unless payload['who']

      "'#{payload['who']}' removed you from the group '#{payload['group']}'"
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
