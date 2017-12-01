module Event
  class CommentForProject < Project
    include CommentEvent
    receiver_roles :maintainer, :watcher
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.comment"
    end

    self.description = 'New comment for project created'

    def subject
      "New comment in project #{payload['project']} by #{User.find(payload['commenter']).login}"
    end
  end
end
