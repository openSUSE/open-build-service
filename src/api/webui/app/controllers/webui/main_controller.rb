class Webui::MainController < Webui::WebuiController

  include Webui::WebuiHelper
  include StatisticsCalculations

  # permissions.status_message_create
  before_filter :require_admin, only: [:delete_message, :add_news]

  def gather_busy
    busy = []
    archs = Architecture.where(available: 1).pluck(:name).map {|arch| map_to_workers(arch)}.uniq
    archs.each do |arch|
      starttime = Time.now.to_i - 168.to_i * 3600
      rel = StatusHistory.where("time >= ? AND \`key\` = ?", starttime, 'building_' + arch)
      values = rel.pluck(:time, :value).collect { |time, value| [time.to_i, value.to_f] }
      busy = Webui::MonitorController.addarrays(busy, StatusHelper.resample(values, 400))
    end
    busy
  end

  def index
    @news = StatusMessage.alive.limit(4).to_a
    @workerstatus = Rails.cache.fetch('workerstatus_hash', expires_in: 10.minutes) do
      WorkerStatus.hidden.to_hash
    end
    @latest_updates = get_latest_updated(6)
    @waiting_packages = 0
    @building_workers = @workerstatus.elements('building').length
    @overall_workers = @workerstatus['clients']
    @workerstatus.elements('waiting') {|waiting| @waiting_packages += waiting['jobs'].to_i}
    @busy = Rails.cache.fetch('mainpage_busy', expires_in: 10.minutes) do
      gather_busy
    end
    @project_count = Project.count
    @package_count = Package.count
    @repo_count = Repository.count
    @user_count = User.count
  end

  def news
    @news = StatusMessage.alive.limit(5)
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime::RSS
    render layout: false
  end

  def latest_updates
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime::RSS
    @latest_updates = get_latest_updated(10)
    render layout: false
  end

  def sitemap
    render :layout => false, :content_type => 'application/xml'
  end

  def require_projects
    @projects = Array.new
    WebuiCollection.find(:id, :what => 'project').each_project do |p|
      @projects << p.value(:name)
    end
  end

  def sitemap_projects
    require_projects
    render :layout => false, :content_type => 'application/xml'
  end
 
  def sitemap_projects_subpage(action, changefreq, priority)
    require_projects
    render :template => 'webui/main/sitemap_projects_subpage', :layout => false, :locals => { :action => action, :changefreq => changefreq, :priority => priority }, :content_type => 'application/xml'
  end

  def sitemap_projects_packages
    sitemap_projects_subpage(:packages, 'monthly', 0.7)
  end

  def sitemap_projects_prjconf
    sitemap_projects_subpage(:prjconf, 'monthly', 0.1)
  end

  def sitemap_packages
    category = params[:category].to_s
    @packages = Array.new
    predicate = ''
    if category =~ %r{home}
      predicate = "starts-with(@project,'#{category}')"
    elsif category == 'opensuse'
      predicate = "starts-with(@project,'openSUSE:')"
    elsif category == 'main'
      predicate = "not(starts-with(@project,'home:')) and not(starts-with(@project,'DISCONTINUED:')) and not(starts-with(@project,'openSUSE:'))"
    end
    WebuiCollection.find(:id, :what => 'package', :predicate => predicate).each_package do |p|
      @packages << [p.value(:project), p.value(:name)]
    end
    render :template => 'webui/main/sitemap_packages', :layout => false, :locals => {:action => params[:listaction]}, :content_type => 'application/xml'
  end

  def add_news_dialog
    render_dialog
  end

  def add_news
    if params[:message].nil? or params[:severity].empty?
      flash[:error] = 'Please provide a message and severity'
      redirect_to(:action => 'index') and return
    end
    #TODO - make use of permissions.status_message_create
    StatusMessage.create!(message: params[:message], severity: params[:severity], user: User.current)
    redirect_to(:action => 'index')
  end

  def delete_message_dialog
    render_dialog
  end

  def delete_message
    required_parameters :message_id
    StatusMessage.find(params[:message_id]).delete
    redirect_to(:action => 'index')
  end

end
