class StatisticsController < ApplicationController


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
  end


  def most_active
  end


  def latest_added
    limit = 10 if (limit = params[:limit].to_i) == 0

    packages = DbPackage.find(:all, :order => 'created_at DESC, name', :limit => limit )
    projects = DbProject.find(:all, :order => 'created_at DESC, name', :limit => limit )

    list = []
    projects.each do |project|
      list << project
    end
    packages.each do |package|
      list << package
    end

    list.sort! { |a,b| b.created_at <=> a.created_at }

    @list = list[0..limit-1]
  end


  def latest_updated
    limit = 10 if (limit = params[:limit].to_i) == 0

    packages = DbPackage.find(:all, :order => 'updated_at DESC, name', :limit => limit )
    projects = DbProject.find(:all, :order => 'updated_at DESC, name', :limit => limit )

    list = []
    projects.each do |project|
      list << project
    end
    packages.each do |package|
      list << package
    end

    list.sort! { |a,b| b.updated_at <=> a.updated_at }

    @list = list[0..limit-1]
  end


  def latest_built
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


end
