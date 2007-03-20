class StatisticsController < ApplicationController


  skip_before_filter :authorize, :only => [
    :index, :latest_added, :latest_updated, :most_downloaded, :highest_rated
  ]


  def index
    @latest_added    = LatestAdded.find( :limit => 10 )
    @latest_updated  = LatestUpdated.find( :limit => 10 )
    @highest_rated   = Rating.find( :limit => 10 )
    @most_active_pac = MostActive.find( :limit => 5, :type => 'packages' )
    @most_active_prj = MostActive.find( :limit => 5, :type => 'projects' )
    @limit = 3
    @most_downloaded = get_download_stats
  end


  def latest_added
    limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @latest_added = LatestAdded.find( :limit => limit )
    render :partial => 'latest_added', :layout => layout, :more => true
  end


  def latest_updated
    limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @latest_updated = LatestUpdated.find( :limit => limit )
    render :partial => 'latest_updated', :layout => layout, :more => true
  end


  def most_active
    limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @most_active_pac = MostActive.find( :limit => limit, :type => 'packages' )
    @most_active_prj = MostActive.find( :limit => limit, :type => 'projects' )
    render :partial => 'most_active', :layout => layout, :more => true
  end


  def most_downloaded
    @limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @most_downloaded = get_download_stats
    render :partial => 'most_downloaded', :layout => layout, :more => true
  end


  def highest_rated
    limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @highest_rated = Rating.find( :limit => limit )
    render :partial => 'highest_rated', :layout => layout, :more => true
  end


  def download_details
    limit = params[:limit]
    project = params[:project]
    package = params[:package]
    repo = params[:repo]
    arch = params[:arch]

    if project and package
      @name = "#{package} (project #{project})"
      @title = 'Package'
      @downloads = Downloadcounter.find(
        :project => project, :package => package,
        :limit => limit
      )
    elsif project and repo
      @name = "#{repo} (project #{project})"
      @title = 'Repository'
      @downloads = Downloadcounter.find(
        :repo, :project => project, :repo => repo, :limit => limit
      )
    elsif project
      @name = project
      @title = 'Project'
      @downloads = Downloadcounter.find(
        :project => project, :limit => limit
      )
    elsif arch
      @name = arch
      @title = 'Architecture'
      @downloads = Downloadcounter.find(
        :arch, :arch => arch, :limit => limit
      )
    else
      @name = 'all downloads'
      @title = ''
      @downloads = Downloadcounter.find( :limit => limit )
    end
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    render :partial => 'download_details', :layout => layout
  end


  private


  def get_download_stats
    most_downloaded = {}
    most_downloaded[:projects] = Downloadcounter.find(
      :group_by => 'project', :limit => @limit
    )
    most_downloaded[:packages] = Downloadcounter.find(
      :group_by => 'package', :limit => @limit
    )
    most_downloaded[:repos] = Downloadcounter.find(
      :group_by => 'repo', :limit => @limit
    )
    most_downloaded[:archs] = Downloadcounter.find(
      :group_by => 'arch', :limit => @limit
    )
    return most_downloaded
  end


end
