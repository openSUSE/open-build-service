# strategy class for the event model
class EventFindSubscribers

  def initialize(event)
    @event = event
  end

  def find_maintainers(obj)
    maintainer = obj.relationships.where(role: Role.rolecache['maintainer'])
    users = maintainer.joins(:user).pluck('users.id')
    users |= maintainer.joins(:groups_users).pluck('groups_users.user_id')
    @toconsider |= @subscriptions.where('package_id is null').where(user_id: users).to_a
    users
  end

  def find_project_maintainers(prj)
    return if prj.nil?
    p = Project.find_by_name(prj)
    # old/deleted project
    return unless p

    # now consider all subscriptions for that specific package
    @toconsider |= @subscriptions.where(project: p).to_a

    @project_maintainers = find_maintainers(p)
  end

  def find_package_maintainers(prj, pkg)
    return if prj.nil? || pkg.nil?
    p = Package.find_by_project_and_name(prj, pkg)
    # old/deleted package
    return unless p

    # now consider all subscriptions for that specific package
    @toconsider |= @subscriptions.where(package: p).to_a

    @package_maintainers = find_maintainers(p)
  end

  def expand_toconsider
    nt = []
    @toconsider.each do |r|
      users=[]
      if r.receive == 'maintainer'
        users.concat @package_maintainers
        users.concat @project_maintainers
      elsif r.receive == 'package_maintainer'
        users.concat @package_maintainers
      else
        nt << r
      end
      users.each do |u|
        e = EventSubscription.new(eventtype: r.eventtype, receive: 'all')
        unless r.user_id.nil?
          next if u != r.user_id
        end
        e.user_id = u
        nt << e
      end
    end

    @toconsider = nt
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
    return false if rules[0].receive == 'none'
    return true
  end

  def filter_toconsider
    users = Hash.new
    @toconsider.each do |r|
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
    @package_maintainers = []
    @project_maintainers = []

    # 2. package maintainers
    find_package_maintainers @payload['project'], @payload['package']
    # for requests
    find_package_maintainers @payload['targetproject'], @payload['targetpackage']

    # 3. project maintainers
    find_project_maintainers @payload['project']
    find_project_maintainers @payload['targetproject']

    # 4. all and none
    usergenerics = @subscriptions.where('package_id is null and project_id is null')
    @toconsider |= usergenerics.where(receive: ['all', 'none']).to_a

    return [] if @toconsider.empty?
    expand_toconsider
    filter_toconsider
  end

end
