require 'statistics_calculations'

class StatisticsController < ApplicationController
  validate_action redirect_stats: { method: :get, response: :redirect_stats }

  before_action :set_limit, only: %i[
    most_active_packages most_active_projects latest_added latest_updated
  ]

  def index
    render plain: 'This is the statistics controller.<br/>See the api documentation for details.'
  end

  def most_active_projects
    # get all packages including activity values
    @packages = Package.select("packages.*, #{Package.activity_algorithm}")
                       .limit(@limit).order('activity_value DESC')
    # count packages per project and sum up activity values
    projects = {}
    @packages.each do |package|
      pro = package.project.name
      projects[pro] ||= { count: 0, activity: 0 }
      projects[pro][:count] += 1
      av = package.activity_value.to_f
      projects[pro][:activity] = av if av > projects[pro][:activity]
    end

    # sort by activity
    @projects = projects.sort do |a, b|
      b[1][:activity] <=> a[1][:activity]
    end

    @projects
  end

  def most_active_packages
    # get all packages including activity values
    @packages = Package.select("packages.*, #{Package.activity_algorithm}")
                       .limit(@limit).order('activity_value DESC')
    @packages
  end

  # FIXME3.0: remove route - activity is a completely useless value and only stored for sorting
  def activity
    @project = Project.get_by_name(params[:project])
    @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_project_links: false) if params[:package]
  end

  def latest_added
    packages = Package.limit(@limit).order('created_at DESC, name').to_a
    projects = Project.limit(@limit).order('created_at DESC, name').to_a

    list = projects
    list.concat(packages)
    list.sort! { |a, b| b.created_at <=> a.created_at }

    @list = if @limit
              list[0..@limit - 1]
            else
              list
            end
  end

  def added_timestamp
    @project = Project.get_by_name(params[:project])
    @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)

    # is it used at all ?
  end

  def latest_updated
    prj_filter = params[:prjfilter]
    pkg_filter = params[:pkgfilter]

    if params[:timelimit].nil?
      @timelimit = nil
    else
      @timelimit = params[:timelimit].to_i.day.ago
      # Override the default, since we want to limit by the time here.
      @limit = nil if params[:limit].nil?
    end

    @list = StatisticsCalculations.get_latest_updated(@limit, @timelimit, prj_filter, pkg_filter)
  end

  def updated_timestamp
    @project = Project.get_by_name(params[:project])
    @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
  end

  def global_counters
    @users = User.count
    @repos = Repository.count
    @projects = Project.count
    @packages = Package.count
  end

  def set_limit
    return @limit = nil if !params[:limit].nil? && params[:limit].to_i.zero?

    @limit = 10 if (@limit = params[:limit].to_i).zero?
  end

  def active_request_creators
    required_parameters :project

    # get the devel projects
    @project = Project.find_by_name!(params[:project])

    # get devel projects
    ids = Package.joins('left outer join packages d on d.develpackage_id = packages.id')
                 .where('d.project_id' => @project.id).distinct.order('packages.project_id').pluck('packages.project_id')
    ids << @project.id
    projects = Project.where(id: ids).pluck(:name)

    # get all requests to it
    actions = BsRequestAction.where(target_project: projects).select(:bs_request_id)
    reqs = BsRequest.where(id: actions).select(%i[id created_at creator])
    if params[:raw] == '1'
      render json: reqs
      return
    end
    reqs = reqs.group_by { |r| r.created_at.strftime('%Y-%m') }
    @stats = []
    reqs.sort.each do |month, requests|
      monstats = requests.group_by(&:creator).sort.map do |creator, list|
        [creator, User.find_by_login(creator).email, list.length]
      end
      @stats << [month, monstats]
    end
    respond_to do |format|
      format.xml
      format.json { render json: @stats }
    end
  end
end
