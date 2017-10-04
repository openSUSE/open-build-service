# strategy class for the event model
class EventFindSubscriptions
  def initialize(event)
    @event = event
  end

  def subscriptions
    @payload = @event.payload
    @subscriptions = EventSubscription.where(eventtype: @event.class.classnames)

    # Get the defaults created by the admin via Webui::SubscriptionsController
    @toconsider = @subscriptions.where('user_id is null AND group_id is null').to_a
    # Create defaults for receiver_roles of this Event
    @event.class.receiver_roles.each do |receiver_role|
      unless receiver_role_set(receiver_role)
        @toconsider << EventSubscription.new(eventtype: @event.class.name, receiver_role: receiver_role, channel: 'disabled')
      end
    end

    return [] if @toconsider.empty?

    expand_toconsider
    filter_toconsider
  end

  private

  # Expand the EventSubscriptions receiver_role.
  # Receivers can be many Users and Groups. We need to instantiate EventSubscriptions
  # for all of them.
  def expand_toconsider
    new_toconsider = []
    @toconsider.each do |subscription|
      new_toconsider.concat(expand_subscription(subscription))
    end
    @toconsider = new_toconsider
  end

  def expand_subscription(subscription_to_expand)
    # Fetch all User/Groups from the Event that match the receiver_role of
    # the EventSubscription
    receivers = @event.send("#{subscription_to_expand.receiver_role}s")

    # Fetch User ids
    user_ids = receivers.select { |reciver| reciver.kind_of? User }.map(&:id)

    # Fetch Group ids
    groups = receivers.select { |reciver| reciver.kind_of? Group }
    group_ids = []
    groups.each do |group|
      # If the group has an email set we'll consider that one
      if group.email
        group_ids << group.id
      else
        # if the Group has no email set we consider all users of it individually
        group.users.each do |user|
          # of course only when the User is "subscribed" to the group
          next unless user_subscribed_to_group_email?(group, user)
          user_ids << user.id
        end
      end
    end

    table = EventSubscription.arel_table

    # First find all the subscriptions that are in the database for Users/Groups
    EventSubscription
      .where(
        eventtype: subscription_to_expand.eventtype,
        receiver_role: subscription_to_expand.receiver_role
      )
      .where(
        table[:user_id].in(user_ids).or(table[:group_id].in(group_ids))
      ).to_a
  end

  # Filter out EventSubscriptions that make no sense or that have an EventSubscription
  # with higher priority
  def filter_toconsider
    subscribers_and_subscriptions = Hash.new

    # Filter out subscriptions without an email. no need to consider it if we
    # can't send mail to anyway...
    @toconsider.each do |subscription|
      next if subscription.subscriber.email.blank?
      subscribers_and_subscriptions[subscription.subscriber] ||= []
      subscribers_and_subscriptions[subscription.subscriber] << subscription
    end

    # Find the most important subscription.
    subscriptions_to_receive = []
    subscribers_and_subscriptions.each do |_subscriber, subscriptions|
      priority_subscription = sort_subscriptions_by_priority(subscriptions).first

      if priority_subscription.enabled?
        subscriptions_to_receive << priority_subscription
      end
    end

    # Filter out subscriptions for the User that has caused the Event. They know
    # what they did, no need to send mail about it...
    subscriptions_to_receive.reject! do |subscription|
      subscription.subscriber == @event.originator
    end

    subscriptions_to_receive
  end

  # Compare two EventSubscription by priority (high to low):
  # 1. EventSubscriptions the admin/Users explicitely have set in the database over
  #    those we have instantiated in memory for all the receiver_roles of the Event
  # 2. EventSubscriptions that are enabled over those that are disabled
  def sort_subscriptions_by_priority(subscriptions)
    subscriptions.sort { |x, y| compare_two_subscriptions(x, y) }
  end

  def compare_two_subscriptions(x, y)
    # prefer subscriptions in the database
    return -1 if x.id && !y.id
    return 1 if !x.id && y.id

    # if both are in database, they may be the same
    if x.id && y.id && x.id == y.id
      return 0
    end

    # without further information, we prefer those that want mail
    return -1 if x.enabled? && y.disabled?
    return 1 if y.enabled? && x.disabled?

    -1
  end

  # FIXME: The email boolean is a 'feature' that you can only access by manually
  #        changing the data of GroupUser. Either we'll do an interface for it
  #        or settle on a default...
  def user_subscribed_to_group_email?(group, user)
    GroupsUser.find_by(group: group, user: user).email
  end

  def receiver_role_set(role)
    @toconsider.any? {|r| r.receiver_role.to_sym == role.to_sym}
  end
end
