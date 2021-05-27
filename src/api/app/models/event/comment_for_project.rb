module Event
  class CommentForProject < Base
    include CommentEvent
    self.message_bus_routing_key = 'project.comment'
    self.description = 'New comment for project created'
    payload_keys :project
    receiver_roles :maintainer, :bugowner, :watcher

    def subject
      "New comment in project #{payload['project']} by #{payload['commenter']}"
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :integer          not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(65535)
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
