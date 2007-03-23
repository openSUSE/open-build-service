class StatisticsController < ApplicationController


  skip_before_filter :authorize, :only => [
    :index, :latest_added, :latest_updated, :most_downloaded, :highest_rated
  ]


  def index
    @latest_added    = LatestAdded.find( :limit => 10 )
    @latest_updated  = LatestUpdated.find( :limit => 10 )
    @highest_rated   = Rating.find( :all, :limit => 10 )
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
    @highest_rated = Rating.find( :all, :limit => limit )
    render :partial => 'highest_rated', :layout => layout, :more => true
  end


  def download_details
    @limit = params[:limit]
    @project = params[:project]
    @package = params[:package]
    @repo = params[:repo]
    @arch = params[:arch]

    @title = 'Filter: &nbsp; '
    @title += "Project=#{@project} &nbsp; "   if @project
    @title += "Package=#{@package} &nbsp; "   if @package
    @title += "Architecture=#{@arch} &nbsp; " if @arch
    @title += "Repository=#{@repo} &nbsp; "   if @repo
    @title = 'All Downloads' unless @project or @package or @arch or @repo

    @downloads = Downloadcounter.find :limit => @limit,
      :project => @project, :package => @package, :repo => @repo, :arch => @arch

    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    render :partial => 'download_details', :layout => layout
  end


  def display_info
    text = '<span>'
    case params[:for]
    when 'download_details'
      text += '<h4>Download Details <img src="/images/info.png" /></h4>'
      text += 'Here you can see download statistics details for packages of '
      text += 'the build service. These statistics are updated twice a day '
      text += 'at the moment, so they are not live.'
    when 'most_downloaded'
      text += '<h4>Most Downloaded <img src="/images/info.png" /></h4>'
      text += 'Here you can see download statistics overview for packages of '
      text += 'the build service. These statistics are updated twice a day '
      text += 'at the moment, so they are not live.'
    when 'highest_rated'
      text += '<h4>Highest Rated <img src="/images/info.png" /></h4>'
      text += 'Here you can see which packages and project were '
      text += 'highest rated by the build service users. Only registered '
      text += 'can rate packages and projects by clicking one of the five '
      text += 'stars next to the header. Only packages/projects with more '
      text += "than #{min_votes_for_rating} ratings are displayed here."
    when 'latest_added'
      text += '<h4>Latest Added <img src="/images/info.png" /></h4>'
      text += 'Here you can see which are the packages and projects last '
      text += 'added.'
    when 'latest_updated'
      text += '<h4>Latest Updated <img src="/images/info.png" /></h4>'
      text += 'Here you can see which are the packages and projects last '
      text += 'updated.'
    when 'most_active'
      text += '<h4>Most Active <img src="/images/info.png" /></h4>'
      text += 'Here you can see the most active packages and projects. '
      text += 'Activity is mainly measured by the update frequency and count'
      text += 'of updates.'
    else
      text += '<h4>Sorry <img src="/images/info.png" /></h4>'
      text += 'no info / help available.'
    end
    text += '</span>'
    render :update do |page|
      page.visual_effect :slide_up, 'infobox', :duration => 0.3
      page.delay(0.75) do
        page.replace_html 'infobox', text
        page.visual_effect :slide_down, 'infobox', :duration => 0.3
      end
    end
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
