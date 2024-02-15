# TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
module Event
  class CreateReport < Base
    receiver_roles :moderator
    self.description = 'Report for inappropriate content has been created'

    payload_keys :id, :user_id, :reportable_id, :reportable_type, :reason

    def parameters_for_notification
      super.merge(notifiable_type: 'Report')
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
