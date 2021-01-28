# Fetch event receivers for a receiver role
#   An event receiver is a user/group wanting to be notified about an event
#   A receiver role is defined on the event itself. It could be a maintainer, bugowner, etc...
class EventReceiversFetcher
  attr_reader :receivers_without_group_members

  def initialize(event, receiver_role)
    @receivers_without_group_members = event.send("#{receiver_role}s")
  end

  def call
    fetch_event_receivers(receivers_without_group_members)
  end

  private

  def fetch_event_receivers(receivers_without_group_members)
    receivers = []

    receivers_without_group_members.each do |receiver|
      case receiver
      when User
        receivers << receiver
      when Group
        receivers += GroupsUsersToNotifyFinder.new(receiver.groups_users).call
      end
    end

    # Filtering out duplicate receivers
    #   For example, users and groups maintaining a package and some of those users are members of those groups.
    #   The users will be returned twice in the receivers array.
    receivers.uniq do |receiver|
      case receiver
      when User
        receiver.id
      when GroupsUser
        receiver.user_id
      end
    end
  end
end
