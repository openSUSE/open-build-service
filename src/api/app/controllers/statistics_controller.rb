class StatisticsController < ApplicationController


  before_filter :get_limit, :only => [
    :highest_rated, :most_downloaded, :most_active,
    :latest_added,  :latest_updated,  :latest_built
  ]

  validate_action :download_stats => :download_stats


  def index
    types = [
      'highest_rated',
      'most_downloaded',
      'most_active',
      'latest_added',
      'latest_updated',
      'latest_built'
    ]
    render :text => "This is the statistics controller.<br/><br/>" +
      "Available statistics types:<br/> #{types.to_sentence(:skip_last_comma=>true)}"
  end


  def highest_rated
  end


  def most_downloaded
    @list = DbPackage.find(:all, :order => 'downloads DESC', :limit => @limit )
  end


  def download_stats
    if request.put?
      data = request.raw_post

      download_stats = ActiveXML::Base.new( data )

      download_stats.each_project do |project|
        project.each_package do |package_stat|
          logger.debug "New download_stats for #{package_stat.name}: count=#{package_stat.to_s}"
          begin
            prj = DbProject.find( :first, :conditions => [ "name = ?", project.name ] )
            pac = DbPackage.find( :first, :conditions => [ "name = ? AND db_project_id = ?", package_stat.name, prj.id ] )
            pac.downloads = package_stat.to_s
            pac.save
          rescue ActiveRecord::RecordNotFound
            logger.debug "Package #{package_stat.name} (project #{prj.name}) does not exist -> ignore counter (#{package_stat})."
            next
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


  def latest_updated
    packages = DbPackage.find(:all, :order => 'updated_at DESC, name', :limit => @limit )
    projects = DbProject.find(:all, :order => 'updated_at DESC, name', :limit => @limit )

    list = []
    projects.each { |project| list << project }
    packages.each { |package| list << package }
    list.sort! { |a,b| b.updated_at <=> a.updated_at }

    @list = list[0..@limit-1]
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


  def randomize_downloads

    # ONLY enable on test-/development database!
    # it will randomize download-counters of ALL packages!
    # this should NOT be enabled for prodution data!
    enable = false
    #

    if enable

      # deactivate automatic timestamps for this action
      ActiveRecord::Base.record_timestamps = false

      packages = DbPackage.find(:all)

      packages.each do |package|
        package.downloads = rand( 10000000 )
        if package.save
          logger.debug "Package #{package.name} got new download counter"
        else
          logger.debug "Package #{package.name} : ERROR setting download counter"
        end
      end

      # re-activate automatic timestamps
      ActiveRecord::Base.record_timestamps = true

      render :text => "ok, done randomizing all download counters."
      return
    else
      logger.debug "tried to execute randomize_downloads, but it's not enabled!"
      render :text => "this action is deactivated."
      return
    end

  end


end
