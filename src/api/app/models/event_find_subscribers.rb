# strategy class for the event model
class EventFindSubscribers

  def initialize(event)
    @event = event
  end

  def expand_toconsider
    Rails.logger.debug "Expand #{@toconsider.inspect}"

    nt = []
    @toconsider.each do |r|
      nt.concat(expand_one_rule(r))
    end

    @toconsider = nt
    Rails.logger.debug "Expanded #{@toconsider.inspect}"
  end

  def expand_one_rule(r)
    if r.receiver_role == :all
      return [r]
    end

    users = @event.send("#{r.receiver_role}s")
    raise "we need an array for #{@event.inspect} -> #{r.receiver_role}" unless users.is_a? Array

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

    return -1
  end

  def check_rules?(rules)
    rules.sort! { |x, y| compare_two_rules(x, y) }
    #rules.each do |r|
    #  puts "R I#{r.id} T:#{r.type} U:#{r.user_id} P#{r.project_id}#{r.package_id}"
    #end
    #puts ""
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
      if r.receiver_role.to_sym == r.receiver_role.to_sym
        return true
      end
    end
    false
  end

  def subscribers
    @payload = @event.payload
    @subscriptions = EventSubscription.where(eventtype: @event.class.classnames)

    # we have 4 different subscription types and each requires a different strategy

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

    Rails.logger.debug "To consider #{@toconsider.inspect}"
    return [] if @toconsider.empty?

    expand_toconsider
    filter_toconsider
  end

end
