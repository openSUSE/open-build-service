class BsRequestCollection

  def extend_relation_for_project(source_or_target)
    if @roles.count == 0 or @roles.include? source_or_target
      @rel = @rel.references(:bs_request_actions)
      if @subprojects.blank?
        @inner_or << "bs_request_actions.#{source_or_target}_project=#{quote(@project)}"
      else
        @inner_or << "(bs_request_actions.#{source_or_target}_project like #{quote(@project + ':%')})"
      end
    end
  end

  def quote(str)
    conn.quote(str)
  end
  
  def conn
    @conn ||= ActiveRecord::Base.connection  
  end
  
  def initialize(opts)
    @roles = opts[:roles] || []
    states = opts[:states] || []
    types = opts[:types] || []
    review_states = opts[:review_states] || %w(new)
    @subprojects = opts[:subprojects]
    @project = opts[:project]
    
    @rel = BsRequest.joins(:bs_request_actions)

    # filter for request state(s)
    unless states.blank?
      @rel = @rel.where('bs_requests.state in (?)', states).references(:bs_requests)
    end

    # Filter by request type (submit, delete, ...)
    unless types.blank?
      @rel = @rel.where('bs_request_actions.type in (?)', types).references(:bs_request_actions)
    end

    unless opts[:project].blank?
      @inner_or = []

      if opts[:package].blank?
        extend_relation_for_project('source')
        extend_relation_for_project('target')

        if @roles.count == 0 or @roles.include? 'reviewer'
          if states.count == 0 or states.include? 'review'
            @rel = @rel.references(:reviews)
            review_states.each do |r|
              @rel = @rel.includes(:reviews)
              @inner_or << "(reviews.state=#{quote(r)} and reviews.by_project=#{quote(opts[:project])})"
            end
          end
        end
      else
        if @roles.count == 0 or @roles.include? 'source'
          @rel = @rel.references(:bs_request_actions)
          @inner_or << "(bs_request_actions.source_project=#{quote(opts[:project])} and bs_request_actions.source_package=#{quote(opts[:package])})"
        end
        if @roles.count == 0 or @roles.include? 'target'
          @rel = @rel.references(:bs_request_actions)
          @inner_or << "(bs_request_actions.target_project=#{quote(opts[:project])} and bs_request_actions.target_package=#{quote(opts[:package])})"
        end
        if @roles.count == 0 or @roles.include? 'reviewer'
          if states.count == 0 or states.include? 'review'
            @rel = @rel.references(:reviews)
            review_states.each do |r|
              @rel = @rel.includes(:reviews)
              @inner_or << "(reviews.state=#{quote(r)} and reviews.by_project=#{quote(opts[:project])} and reviews.by_package=#{quote(opts[:package])})"
            end
          end
        end
      end

      if @inner_or.count > 0
        @rel = @rel.where(@inner_or.join(' or '))
      end
    end

    if opts[:user]
      @inner_or = []
      user = User.get_by_login(opts[:user])
      # user's own submitted requests
      if @roles.count == 0 or @roles.include? 'creator'
        @inner_or << "bs_requests.creator = #{quote(user.login)}"
      end

      # find requests where user is maintainer in target project
      if @roles.count == 0 or @roles.include? 'maintainer'
        names = user.involved_projects.map { |p| p.name }
        @rel = @rel.references(:bs_request_actions)
        @inner_or << "bs_request_actions.target_project in ('" + names.join("','") + "')"

        ## find request where user is maintainer in target package, except we have to project already
        user.involved_packages.each do |ip|
          @rel = @rel.references(:bs_request_actions)
          @inner_or << "(bs_request_actions.target_project='#{ip.project.name}' and bs_request_actions.target_package='#{ip.name}')"
        end
      end

      if @roles.count == 0 or @roles.include? 'reviewer'
        @rel = @rel.includes(:reviews).references(:reviews)
        review_states.each do |r|

          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = ["reviews.by_user=#{quote(user.login)}"]
          # include all groups of user
          usergroups = user.groups.map { |g| "'#{g.title}'" }
          or_in_and << "reviews.by_group in (#{usergroups.join(',')})" unless usergroups.blank?

          # find requests where user is maintainer in target project
          userprojects = user.involved_projects.select('projects.name').map { |p| "'#{p.name}'" }
          or_in_and << "reviews.by_project in (#{userprojects.join(',')})" unless userprojects.blank?

          ## find request where user is maintainer in target package, except we have to project already
          user.involved_packages.select('name,db_project_id').includes(:project).each do |ip|
            or_in_and << "(reviews.by_project='#{ip.project.name}' and reviews.by_package='#{ip.name}')"
          end

          @inner_or << "(reviews.state=#{quote(r)} and (#{or_in_and.join(' or ')}))"
        end
      end

      unless @inner_or.empty?
        @rel = @rel.where(@inner_or.join(' or '))
      end
    end

    if opts[:group]
      @inner_or = []
      group = Group.get_by_title(opts[:group])

      # find requests where group is maintainer in target project
      if @roles.count == 0 or @roles.include? 'maintainer'
        names = group.involved_projects.map { |p| p.name }
        @rel = @rel.references(:bs_request_actions)
        @inner_or << "bs_request_actions.target_project in ('" + names.join("','") + "')"

        ## find request where group is maintainer in target package, except we have to project already
        group.involved_packages.each do |ip|
          @inner_or << "(bs_request_actions.target_project='#{ip.project.name}' and bs_request_actions.target_package='#{ip.name}')"
        end
      end

      if @roles.count == 0 or @roles.include? 'reviewer'
        @rel = @rel.includes(:reviews).references(:reviews)

        review_states.each do |r|

          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = ["reviews.by_group='#{group.title}'"]

          # find requests where group is maintainer in target project
          groupprojects = group.involved_projects.select('projects.name').map { |p| "'#{p.name}'" }
          or_in_and << "reviews.by_project in (#{groupprojects.join(',')})" unless groupprojects.blank?

          ## find request where user is maintainer in target package, except we have to project already
          group.involved_packages.select('name,db_project_id').includes(:project).each do |ip|
            or_in_and << "(reviews.by_project='#{ip.project.name}' and reviews.by_package='#{ip.name}')"
          end

          @inner_or << "(reviews.state='#{r}' and (#{or_in_and.join(' or ')}))"
        end
      end

      unless @inner_or.empty?
        @rel = @rel.where(@inner_or.join(' or '))
      end
    end

    if opts[:ids]
      @rel = @rel.where(:id => opts[:ids])
    end
  end

  def ids
    @rel.pluck("bs_requests.id")
  end

  def relation
    @rel
  end

end
