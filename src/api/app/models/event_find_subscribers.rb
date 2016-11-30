# strategy class for the event model
class EventFindSubscribers
  def initialize(event)
    @event = event
  end

  def expand_toconsider
    nt = []
    @toconsider.each do |r|
      nt.concat(expand_one_rule(r))
    end
    @toconsider = nt
    @toconsider.each do |t|
      Rails.logger.debug "Expanded #{t.inspect}"
    end
  end

  def expand_one_rule(r)
    if r.receiver_role == :all
      return [r]
    end

    receivers = @event.send("#{r.receiver_role}s")
    receivers.each do |u|
      Rails.logger.debug "Event for receiver_role #{r.receiver_role} goes to #{u}"
    end

    # fetch database settings
    user_ids = receivers.select { |rcv| rcv.kind_of? User }.map { |u| u.id }
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

  def compare_two_rules(x, y)
    # prefer rules in the database
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

  def check_rules?(rules)
    rules.sort! { |x, y| compare_two_rules(x, y) }
    return false if !rules[0].receive
    true
  end

  def user_subscribed_to_group_email?(group, user)
    GroupsUser.find_by(group: group, user: user).email
  end

  def filter_toconsider
    receivers = Hash.new

    @toconsider.each do |r|
      if r.group_id
        group = Group.find(r.group_id)
        next if group.email.blank?
        receivers[group] ||= Array.new
        receivers[group] << r
      end

      # add users
      next unless r.user_id
      u = User.find(r.user_id)
      receivers[u] ||= Array.new
      receivers[u] << r
    end

    ret=[]
    receivers.each do |rcv, rules|
      if check_rules? rules
        ret << rcv
      end
    end

    ret
  end

  def receiver_role_set(role)
    @toconsider.any? {|r| r.receiver_role.to_sym == role.to_sym} ? true : false
  end

  def subscribers
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

    @toconsider.each do |t|
      Rails.logger.debug "To consider #{t.inspect}"
    end
    return [] if @toconsider.empty?

    expand_toconsider
    filter_toconsider
  end
end
