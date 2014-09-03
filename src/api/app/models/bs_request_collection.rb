class BsRequestCollection

  def initialize(opts)
    @roles = opts[:roles] || []
    @states = opts[:states] || []
    types = opts[:types] || []
    @review_states = opts[:review_states] || %w(new)
    @subprojects = opts[:subprojects]
    @project = opts[:project]
    @rel = BsRequest.joins(:bs_request_actions).distinct.order(priority: :desc, id: :desc)

    # filter for request state(s)
    unless @states.blank?
      @rel = @rel.where('bs_requests.state in (?)', @states).references(:bs_requests)
    end

    # Filter by request type (submit, delete, ...)
    unless types.blank?
      @rel = @rel.where('bs_request_actions.type in (?)', types).references(:bs_request_actions)
    end

    unless @project.blank?
      @package = opts[:package]
      wrapper_for_inner_or { extend_query_for_project }
    end

    if opts[:user]
      wrapper_for_inner_or { extend_query_for_user(opts[:user]) }
    end

    if opts[:group]
      wrapper_for_inner_or { extend_query_for_group(opts[:group]) }
    end

    if opts[:ids]
      @rel = @rel.where(id: opts[:ids])
    end
  end

  def ids
    @rel.pluck('distinct bs_requests.id')
  end

  def relation
    @rel
  end

  def self.list_ids(opts)
    # All types means don't pass 'type'
    if opts[:types] == 'all' || (opts[:types].respond_to?(:include?) && opts[:types].include?('all'))
      opts.delete(:types)
    end
    # Do not allow a full collection to avoid server load
    if opts[:project].blank? && opts[:user].blank? && opts[:package].blank?
      raise RuntimeError, 'This call requires at least one filter, either by user, project or package'
    end
    roles = opts[:roles] || []
    states = opts[:states] || []

    # it's wiser to split the queries
    if opts[:project] && roles.empty? && (states.empty? || states.include?('review'))
      rel = BsRequestCollection.new(opts.merge({ roles: %w(reviewer) }))
      ids = rel.ids
      rel = BsRequestCollection.new(opts.merge({ roles: %w(target source) }))
    else
      rel = BsRequestCollection.new(opts)
      ids = []
    end
    ids.concat(rel.ids)
  end

  private

  def extend_query_for_maintainer(obj)
    if @roles.count == 0 or @roles.include? 'maintainer'
      names = obj.involved_projects.pluck('name').map { |p| quote(p) }
      @rel = @rel.references(:bs_request_actions)
      @inner_or << "bs_request_actions.target_project in (#{names.join(',')})" unless names.empty?

      ## find request where group is maintainer in target package, except we have to project already
      obj.involved_packages.each do |ip|
        @inner_or << "(bs_request_actions.target_project='#{ip.project.name}' and bs_request_actions.target_package='#{ip.name}')"
      end
    end
  end

  def wrapper_for_inner_or
    @inner_or = []
    yield
    if @inner_or.empty?
      @rel = @rel.where('1=0')
    else
      @rel = @rel.where(@inner_or.join(' or '))
    end
  end

  def extend_query_for_involved_reviews(obj, or_in_and)
    @review_states.each do |r|
      # find requests where obj is maintainer in target project
      projects = obj.involved_projects.pluck('projects.name').map { |p| quote(p) }
      or_in_and << "reviews.by_project in (#{projects.join(',')})" unless projects.blank?

      ## find request where user is maintainer in target package, except we have to project already
      obj.involved_packages.select('name,project_id').includes(:project).each do |ip|
        or_in_and << "(reviews.by_project='#{ip.project.name}' and reviews.by_package='#{ip.name}')"
      end

      @inner_or << "(reviews.state=#{quote(r)} and (#{or_in_and.join(' or ')}))"
    end

  end

  def extend_query_for_group(group)
    group = Group.find_by_title!(group)

    # find requests where group is maintainer in target project
    extend_query_for_maintainer(group)

    if @roles.count == 0 or @roles.include? 'reviewer'
      @rel = @rel.includes(:reviews).references(:reviews)
      # requests where the user is reviewer or own requests that are in review by someone else
      or_in_and = %W(reviews.by_group=#{quote(group.title)})

      extend_query_for_involved_reviews(group, or_in_and)
    end
  end

  def extend_query_for_user(user)
    user = User.find_by_login!(user)

    # user's own submitted requests
    if @roles.count == 0 or @roles.include? 'creator'
      @inner_or << "bs_requests.creator = #{quote(user.login)}"
    end

    # find requests where user is maintainer in target project
    extend_query_for_maintainer(user)

    if @roles.count == 0 or @roles.include? 'reviewer'
      @rel = @rel.includes(:reviews).references(:reviews)

      # requests where the user is reviewer or own requests that are in review by someone else
      or_in_and = %W(reviews.by_user=#{quote(user.login)})

      # include all groups of user
      usergroups = user.groups.map { |g| "'#{g.title}'" }
      or_in_and << "reviews.by_group in (#{usergroups.join(',')})" unless usergroups.blank?

      extend_query_for_involved_reviews(user, or_in_and)
    end
  end

  def extend_relation(source_or_target)
    if @roles.count == 0 or @roles.include? source_or_target
      @rel = @rel.references(:bs_request_actions)
      if @package.blank?
        if @subprojects.blank?
          @inner_or << "bs_request_actions.#{source_or_target}_project=#{quote(@project)}"
        else
          @inner_or << "(bs_request_actions.#{source_or_target}_project like #{quote(@project + ':%')})"
        end
      else
        @inner_or << "(bs_request_actions.#{source_or_target}_project=#{quote(@project)} and " +
            "bs_request_actions.#{source_or_target}_package=#{quote(@package)})"
      end
    end
  end

  def quote(str)
    conn.quote(str)
  end

  def conn
    @conn ||= ActiveRecord::Base.connection
  end

  def extend_query_for_project
    extend_relation('source')
    extend_relation('target')

    if @roles.count == 0 or @roles.include? 'reviewer'
      if @states.count == 0 or @states.include? 'review'
        @rel = @rel.references(:reviews)
        @review_states.each do |r|
          @rel = @rel.includes(:reviews)
          if @package.blank?
            @inner_or << "(reviews.state=#{quote(r)} and reviews.by_project=#{quote(@project)})"
          else
            @inner_or << "(reviews.state=#{quote(r)} and reviews.by_project=#{quote(@project)} and reviews.by_package=#{quote(@package)})"
          end
        end
      end
    end
  end

end
