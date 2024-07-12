module Event
  class AddedUserToGroup < Base
    self.description = 'Added member to group'
    payload_keys :group, :member, :who

    receiver_roles :member

    self.notification_explanation = 'Receive notifications when you are added to a group.'

    def subject
      return "You were added to the group '#{payload['group']}'" unless payload['who']

      "'#{payload['who']}' added you to the group '#{payload['group']}'"
    end

    def members
      [User.find_by(login: payload['member'])]
    end

    def originator
      payload_address('who')
    end

    def parameters_for_notification
      super.merge({ notifiable_type: 'Group',
                    notifiable_id: Group.find_by(title: payload['group']).id,
                    type: 'NotificationGroup' })
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
