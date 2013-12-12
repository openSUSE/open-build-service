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

    Rails.logger.debug "Expanded #{@toconsider.inspect}"
    @toconsider = nt
  end

  def expand_one_rule(r)
    ret = []
    users=[]
    if [:commenter, :target_maintainer, :reviewer, :maintainer].include?(r.receiver_role)
      nu = @event.send("#{r.receiver_role}s")
      raise "we need an array for #{@event.inspect} -> #{r.receiver_role}" unless nu.is_a? Array
      users.concat(nu)
    elsif r.receiver_role == :creator
      users << @event.creator
    elsif r.receiver_role == :all
      ret << r
    else
      raise "unknown receive? #{r.inspect}"
    end
    users.each do |u|
      e = EventSubscription.new(eventtype: r.eventtype, receiver_role: :all)
      unless r.user_id.nil?
        next if u != r.user_id
      end
      e.user_id = u
      ret << e
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

    return 1 if (y.package_id || y.project_id)
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

  def subscribers
    @payload = @event.payload
    @subscriptions = EventSubscription.where(eventtype: @event.class.classnames)

    # we have 4 different subscription types and each requires a different strategy

    # 1. generic defaults
    @toconsider = @subscriptions.where('user_id is null and package_id is null and project_id is null').to_a

    # 2. user specifics
    usergenerics = @subscriptions.where('package_id is null and project_id is null')
    @toconsider |= usergenerics.where(receiver_role: :all).to_a

    Rails.logger.debug "To consider #{@toconsider.inspect}"
    return [] if @toconsider.empty?

    expand_toconsider
    filter_toconsider
  end

end
