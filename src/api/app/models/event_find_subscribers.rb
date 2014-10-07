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
      Rails.logger.debug "Event for receiver_role #{r.receiver_role} goes to user #{u.login}" if u.kind_of? User
      Rails.logger.debug "Event for receiver_role #{r.receiver_role} goes to group #{u.title}" if u.kind_of? Group
    end

    # fetch database settings
    users = receivers.map { |rcv| rcv if rcv.kind_of? User }
    groups = receivers.map { |rcv| rcv if rcv.kind_of? Group }
    ret=[]
    ret.concat(EventSubscription.where(eventtype: r.eventtype, receiver_role: r.receiver_role, user_id: users)) if users.length > 0
    ret.concat(EventSubscription.where(eventtype: r.eventtype, receiver_role: r.receiver_role, group_id: groups)) if groups.length > 0

    receivers.each do |ug|
      # add a default
      ret << EventSubscription.new(eventtype: r.eventtype, receiver_role: r.receiver_role, receive: r.receive, user_id: ug.id) if ug.kind_of? User
      ret << EventSubscription.new(eventtype: r.eventtype, receiver_role: r.receiver_role, receive: r.receive, group_id: ug.id) if ug.kind_of? Group
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
    ret=[]

    users = Hash.new
    groups = Hash.new
    @toconsider.each do |r|
      if r.group_id
        group = Group.find(r.group_id)
        if group.email
          # group has a common email configured
          groups[group] ||= Array.new
          groups[group] << r
        else
          # it has not, so write all users individually
          group.users.each do |u|
            next unless GroupsUser.where(group: group, user: u).first.email
            users[u] ||= Array.new
            users[u] << r
          end
        end
      end

      next unless r.user_id
      user = User.find(r.user_id)
      users[user] ||= Array.new
      users[user] << r
    end

    users.each do |user, rules|
      if check_rules? rules
        ret << user
      end
    end

    groups.each do |group, rules|
      if check_rules? rules
        ret << group
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
