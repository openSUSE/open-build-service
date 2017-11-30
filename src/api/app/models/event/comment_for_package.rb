class Event::CommentForPackage < ::Event::Package
  include CommentEvent
  receiver_roles :maintainer, :watcher
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.package.comment"
  end

  self.description = 'New comment for package created'

  def subject
    "New comment in package #{payload['project']}/#{payload['package']} by #{User.find(payload['commenter']).login}"
  end
end
