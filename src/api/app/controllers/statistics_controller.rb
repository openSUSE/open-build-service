class StatisticsController < ApplicationController


  before_filter :get_limit, :only => [
    :highest_rated, :most_active, :latest_added, :latest_updated, :latest_built,
    :download_counter
  ]

  validate_action :redirect_stats => :redirect_stats


  def index
    text =  "This is the statistics controller.<br/><br/>"
    text << "Available statistics:<br/>"
    text << "<a href='latest_added'>latest_added</a><br/>"
    text << "<a href='latest_updated'>latest_updated</a><br/>"
    text << "<a href='download_counter'>download_counter</a> / "
    text << "<a href='download_counter?concat=package'>concat mode</a><br/>"
    render :text => text
  end


  def highest_rated
    @ratings = Rating.find :all,
      :select => 'object_id, object_type, count(score) as count,' +
        'sum(score)/count(score) as score_calculated',
      :group => 'object_id, object_type',
      :order => 'score_calculated DESC',
      :limit => @limit
  end


  def rating
    @package = params[:package]
    @project = params[:project]

    begin
      object = DbProject.find_by_name @project
      object = DbPackage.find :first, :conditions =>
        [ 'name=? AND db_project_id=?', @package, object.id ] if @package
      throw if object.nil?
    rescue
      @package = @project = @rating = object = nil
      return
    end

    if request.get?

      @rating = object.rating( @http_user.id )

    elsif request.put?

      # try to get previous rating of this user for this object
      previous_rating = Rating.find :first, :conditions => [
        'object_type=? AND object_id=? AND user_id=?',
        object.class.name, object.id, @http_user.id
      ]
      data = ActiveXML::Base.new( request.raw_post )
      if previous_rating
        # update previous rating
        previous_rating.score = data.to_s.to_i
        previous_rating.save
      else
        # create new rating entry
        begin
          rating = Rating.new
          rating.score = data.to_s.to_i
          rating.object_type = object.class.name
          rating.object_id = object.id
          rating.user_id = @http_user.id
          rating.save
        rescue
          render_error :status => 400, :errorcode => "error setting rating",
            :message => "rating not saved"
          return
        end
      end
      render_ok

    else
      render_error :status => 400, :errorcode => "invalid_method",
        :message => "only GET or PUT method allowed for this action"
    end
  end


  def download_counter

    project = params[:project]
    package = params[:package]
    repository = params[:repository]
    architecture = params[:architecture]

    prj = get_project project
    pac = get_package package, prj.id if prj
    repo = Repository.find_by_name repository
    arch = Architecture.find_by_name architecture

    # return immediately, if object is invalid
    return if not prj  and not project.nil?
    return if not pac  and not package.nil?
    return if not repo and not repository.nil?
    return if not arch and not architecture.nil?

    # get statistics
    prj_stats  = prj.download_stats  if prj
    pac_stats  = pac.download_stats  if pac
    repo_stats = repo.download_stats if repo
    arch_stats = arch.download_stats if arch

    @stats = DownloadStat.find :all

    # get intersection of wanted statistics
    @stats &= prj_stats  if prj_stats
    @stats &= pac_stats  if pac_stats
    @stats &= repo_stats if repo_stats
    @stats &= arch_stats if arch_stats

    # sort by counter in descending order, but not if concat-mode (sort later then)
    @stats.sort! { |a,b| b.count <=> a.count } unless params[:concat]

    # calculate grand total count of downloads
    @sum = 0
    @stats.each { |stat| @sum += stat.count }

    # get timestamp of first counted entry
    first = Time.now
    @stats.each { |stat| first = stat.created_at if stat.created_at < first }
    @first_count = first.xmlschema

    if params[:concat]
      @type = params[:concat]
      # concatenate stats (similar to sql group-by)
      cstats = concat_stats( @stats, @type )

      # sort by count - converts hash to nested array
      @cstats = cstats.sort { |a,b| b[1][:count] <=> a[1][:count] }

      # apply limit
      @cstats = @cstats[0..@limit-1] if @limit
    else
      # apply limit
      @stats = @stats[0..@limit-1] if @limit
    end
  end


  def redirect_stats

    # check permissions
    unless permissions.set_download_counters
      render_error :status => 403, :errorcode => "permission denied",
        :message => "download counters cannot be set, insufficient permissions"
      return
    end

    # get download statistics from redirector as xml
    if request.put?
      download_stats = ActiveXML::Base.new( request.raw_post )

      download_stats.each_project do |project|
        project.each_package do |package|
          package.each_repository do |repository|
            repository.each_arch do |arch|
              arch.each_count do |count|

                # get ids / foreign keys
                begin
                  project_id = DbProject.find( :first,
                    :conditions => [ 'name = ?', project.name ] ).id
                  package_id = DbPackage.find( :first,
                    :conditions => [ 'name = ? AND db_project_id = ?',
                    package.name, project_id ] ).id
                  repository_id = Repository.find( :first,
                      :conditions => [ 'name = ?', repository.name ] ).id
                  architecture_id = Architecture.find( :first,
                      :conditions => [ 'name = ?', arch.name ] ).id
                rescue
                  logger.debug "ERROR: cannot find id(s) for download_stats"
                  next
                end

                # try to find existing entry
                ds = DownloadStat.find :first, :conditions => [
                  'db_project_id=? AND db_package_id=? AND repository_id=? AND ' +
                  'architecture_id=? AND filename=? AND filetype=? AND ' +
                  'version=? AND download_stats.release=?',
                   project_id, package_id, repository_id, architecture_id,
                   count.filename, count.filetype, count.version, count.release
                ]

                if ds
                  # entry found, update it...
                  ds.count = count.to_s
                  ds.save
                else
                  # create new entry
                  ds = DownloadStat.new
                  begin
                    ds.db_project_id = project_id
                    ds.db_package_id = package_id
                    ds.repository_id = repository_id
                    ds.architecture_id = architecture_id
                    ds.filename = count.filename
                    ds.filetype = count.filetype
                    ds.version  = count.version
                    ds.release  = count.release
                    ds.created_at = count.created_at
                    ds.counted_at = count.counted_at
                    ds.count = count.to_s
                  rescue
                    logger.debug "ERROR: cannot create download_stats entry for project #{project.name} / package #{package.name}"
                    logger.debug "DEBUG: #{project.inspect}"
                  end
                  ds.save
                end

              end
            end
          end
        end
      end

      render_ok
    else
      render_error :status => 400, :errorcode => "only_put_method_allowed",
        :message => "only PUT method allowed for this action"
      logger.debug "Tried to access download_stats via '#{request.method}' - not allowed!"
      return
    end
  end


  def most_active
  end


  def latest_added
    packages = DbPackage.find(:all, :order => 'created_at DESC, name', :limit => @limit )
    projects = DbProject.find(:all, :order => 'created_at DESC, name', :limit => @limit )

    list = []
    projects.each { |project| list << project }
    packages.each { |package| list << package }
    list.sort! { |a,b| b.created_at <=> a.created_at }

    @list = list[0..@limit-1]
  end


  def added_timestamp
    @project = DbProject.find_by_name( params[:project] )
    @package = DbPackage.find( :first, :conditions =>
      [ 'name=? AND db_project_id=?', params[:package], @project.id ]
    ) if @project
    logger.debug "=====> project #{@project.inspect}  package #{@package.inspect}  "
  end


  def latest_updated
    packages = DbPackage.find(:all, :order => 'updated_at DESC, name', :limit => @limit )
    projects = DbProject.find(:all, :order => 'updated_at DESC, name', :limit => @limit )

    list = []
    projects.each { |project| list << project }
    packages.each { |package| list << package }
    list.sort! { |a,b| b.updated_at <=> a.updated_at }

    @list = list[0..@limit-1]
  end


  def updated_timestamp
    @project = DbProject.find_by_name( params[:project] )
    @package = DbPackage.find( :first, :conditions =>
      [ 'name=? AND db_project_id=?', params[:package], @project.id ]
    ) if @project
  end


  def latest_built
  end


  def get_limit
    @limit = 10 if (@limit = params[:limit].to_i) == 0
  end


  def randomize_timestamps

    # ONLY enable on test-/development database!
    # it will randomize created/updated timestamps of ALL packages/projects!
    # this should NOT be enabled for prodution data!
    enable = false
    #

    if enable

      # deactivate automatic timestamps for this action
      ActiveRecord::Base.record_timestamps = false

      projects = DbProject.find(:all)
      packages = DbPackage.find(:all)

      projects.each do |project|
        date_min = Time.utc 2005, 9
        date_max = Time.now
        date_diff = ( date_max - date_min ).to_i
        t = [ (date_min + rand(date_diff)), (date_min + rand(date_diff)) ]
        t.sort!
        project.created_at = t[0]
        project.updated_at = t[1]
        if project.save
          logger.debug "Project #{project.name} got new timestamps"
        else
          logger.debug "Project #{project.name} : ERROR setting timestamps"
        end
      end

      packages.each do |package|
        date_min = Time.utc 2005, 6
        date_max = Time.now - 36000
        date_diff = ( date_max - date_min ).to_i
        t = [ (date_min + rand(date_diff)), (date_min + rand(date_diff)) ]
        t.sort!
        package.created_at = t[0]
        package.updated_at = t[1]
        if package.save
          logger.debug "Package #{package.name} got new timestamps"
        else
          logger.debug "Package #{package.name} : ERROR setting timestamps"
        end
      end

      # re-activate automatic timestamps
      ActiveRecord::Base.record_timestamps = true

      render :text => "ok, done randomizing all timestams."
      return
    else
      logger.debug "tried to execute randomize_timestamps, but it's not enabled!"
      render :text => "this action is deactivated."
      return
    end

  end


  private


  def get_project( name )
    prj = DbProject.find( :first,
      :conditions => [ 'name=?', name ]
    )
  end


  def get_package( name, project_id )
    prj = DbPackage.find( :first,
      :conditions => [
        'name=? AND db_project_id=?',
        name, project_id
      ]
    )
  end


  def concat_stats( stats, type )
    # concatenate stats (similar to sql group-by)
    cstats = {}
    case type
    when 'project' ; type = 'db_project'
    when 'package' ; type = 'db_package'
    end
    stats.each do |stat|
      key = stat.send(type).name
      cstats[key] ||= {}
      cstats[key] = {
        :count => cstats[key][:count].to_i + stat.count,
        :files => cstats[key][:files].to_i + 1
      }
      cstats[key][:project] ||= stat.db_project.name if type == 'db_package'
    end
    return cstats
  end


end
