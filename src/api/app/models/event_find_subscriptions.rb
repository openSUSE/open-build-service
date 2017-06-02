# strategy class for the event model
class EventFindSubscriptions
  def initialize(event)
    @event = event
  end

  def subscriptions
    @payload = @event.payload
    @subscriptions = EventSubscription.where(eventtype: @event.class.classnames)

    # 1. generic defaults
    @toconsider = @subscriptions.where('user_id is null AND group_id is null').to_a
    @event.class.receiver_roles.each do |r|
      unless receiver_role_set(r)
        @toconsider << EventSubscription.new(eventtype: @event.class.name, receiver_role: r, receive: false)
      end
    end

    # 2. user and group specifics
    generics = @subscriptions
    @toconsider |= generics.where(receiver_role: :all).to_a

    return [] if @toconsider.empty?

    expand_toconsider
    filter_toconsider
  end

  private

  def expand_toconsider
    new_toconsider = []
    @toconsider.each do |subscription|
      new_toconsider.concat(expand_one_rule(subscription))
    end
    @toconsider = new_toconsider
  end

  def expand_one_rule(r)
    if r.receiver_role == :all
      return [r]
    end

    receivers = @event.send("#{r.receiver_role}s")

    # fetch database settings
    user_ids = receivers.select { |rcv| rcv.kind_of? User }.map(&:id)
    groups = receivers.select { |rcv| rcv.kind_of? Group }
    group_ids = []
    groups.each do |group|
      if group.email
        group_ids << group.id
      else
        # it has not, so write to all users individually
        group.users.each do |u|
          next unless user_subscribed_to_group_email?(group, u)
          user_ids << u.id
        end
      end
    end

    table = EventSubscription.arel_table

    rel = EventSubscription.where(eventtype: r.eventtype, receiver_role: r.receiver_role)
    ret = rel.where(table[:user_id].in(user_ids).or(table[:group_id].in(group_ids))).to_a

    receivers.each do |ug|
      # add a default
      nes = EventSubscription.new(eventtype: r.eventtype, receiver_role: r.receiver_role, receive: r.receive)
      if ug.kind_of? User
        nes.user = ug
      else
        nes.group = ug
      end
      ret << nes
    end
    ret
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
    return -1 if x.receive && !y.receive
    return 1 if y.receive && !x.receive

    -1
  end

  def sort_subscriptions_by_priority(subscriptions)
    subscriptions.sort { |x, y| compare_two_subscriptions(x, y) }
  end

  def user_subscribed_to_group_email?(group, user)
    GroupsUser.find_by(group: group, user: user).email
  end

  def filter_toconsider
    subscribers_and_subscriptions = Hash.new

    @toconsider.each do |subscription|
      subscribers_and_subscriptions[subscription.subscriber] ||= []
      subscribers_and_subscriptions[subscription.subscriber] << subscription
    end

    subscriptions_to_receive = []
    subscribers_and_subscriptions.each do |subscriber, subscriptions|
      sorted_subscriptions = sort_subscriptions_by_priority(subscriptions)
      subscriptions_to_receive << sorted_subscriptions.first
    end

    subscriptions_to_receive.reject! do |subscription|
      subscription.subscriber == @event.originator
    end

    subscriptions_to_receive
  end

  def receiver_role_set(role)
    @toconsider.any? {|r| r.receiver_role.to_sym == role.to_sym}
  end
end
