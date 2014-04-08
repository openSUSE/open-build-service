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

    users = @event.send("#{r.receiver_role}s")
    users.each do |u|
      Rails.logger.debug "Event for receiver_role #{r.receiver_role} goes to user #{u}"
    end

    # fetch database settings
    ret = EventSubscription.where(eventtype: r.eventtype, receiver_role: r.receiver_role, user_id: users).to_a

    users.each do |u|
      # add a default
      ret << EventSubscription.new(eventtype: r.eventtype, receiver_role: r.receiver_role, receive: r.receive, user_id: u)
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

    return -1
  end

  def check_rules?(rules)
    rules.sort! { |x, y| compare_two_rules(x, y) }
    return false if !rules[0].receive
    return true
  end

  def filter_toconsider
    users = Hash.new
    @toconsider.each do |r|
      next unless r.user_id
      users[r.user_id] ||= Array.new
      users[r.user_id] << r
    end
    ret=[]
    users.each do |user, rules|
      if check_rules? rules
        ret << user
      end
    end
    ret
  end

  def receiver_role_set(role)
    @toconsider.each do |r|
      if r.receiver_role.to_sym == role.to_sym
        return true
      end
    end
    false
  end

  def subscribers
    @payload = @event.payload
    @subscriptions = EventSubscription.where(eventtype: @event.class.classnames)

    # 1. generic defaults
    @toconsider = @subscriptions.where('user_id is null').to_a
    @event.class.receiver_roles.each do |r|
      unless receiver_role_set(r)
        @toconsider << EventSubscription.new(eventtype: @event.class.name, receiver_role: r, receive: false)
      end
    end

    # 2. user specifics
    usergenerics = @subscriptions
    @toconsider |= usergenerics.where(receiver_role: :all).to_a


    @toconsider.each do |t|
      Rails.logger.debug "To consider #{t.inspect}"
    end
    return [] if @toconsider.empty?

    expand_toconsider
    filter_toconsider
  end

end
