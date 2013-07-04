# require 'project_status'
# require 'collection'
# require 'buildresult'
# require 'role'
# require 'package'
# require 'json'

class ProjectController < ApplicationController

  include ApplicationHelper
  include RequestHelper

  before_filter :load_project_info, :only => [:show]
  before_filter :require_project, :except => [:repository_arch_list,
    :autocomplete_projects, :autocomplete_incidents, :clear_failed_comment, :edit_comment_form, :index, 
    :list, :list_all, :list_public, :new, :package_buildresult, :save_new, :save_prjconf,
    :rebuild_time_png, :new_incident, :show]
  before_filter :require_login, :only => [:save_new, :toggle_watch, :delete, :new]
  before_filter :require_available_architectures, :only => [:add_repository, :add_repository_from_default_list, 
                                                            :edit_repository, :update_target]

  before_filter :load_releasetargets, :only => [ :show, :incident_request_dialog ]
  prepend_before_filter :lockout_spiders, :only => [:requests, :rebuild_time]

  def index
    redirect_to :action => 'list_public'
  end

  def list_all
    list and return
  end

  def list_public
    params['excludefilter'] = 'home:'
    list and return
  end

  def list
    all_projects = ApiDetails.find(:all_projects)
    @important_projects = []
    @main_projects = []
    @excl_projects = []
    if params['excludefilter'] and params['excludefilter'] != 'undefined'
      @excludefilter = params['excludefilter']
    else
      @excludefilter = nil
    end
    all_projects.each do |name, infos|
      if infos['important']
        @important_projects << [name, infos['title']]
      end
      if @excludefilter && name.start_with?(@excludefilter)
        @excl_projects << [name, infos['title']]
      else
        @main_projects << [name, infos['title']]
      end
    end
    # excl and main are sorted by datatable, but important need to be in order
    @important_projects.sort! {|a,b| a[0] <=> b[0] }
    render :list, :status => params[:nextstatus]
  end

  def autocomplete_projects
    required_parameters :term
    get_filtered_projectlist params[:term], ''
    render :json => @projects
  end

  def autocomplete_incidents
    required_parameters :term
    get_filtered_projectlist params[:term], '', :only_incidents => true
    render :json => @projects
  end

  def autocomplete_packages
    required_parameters :term
    if valid_package_name_read?( params[:term] ) or params[:term] == ""
      render :json => @project.packages.select{|p| p.name.index(params[:term]) }.map{|p| p.name}
    else
      render :text => '[]'
    end
  end

  def autocomplete_repositories
    render :json => @project.repositories
  end

  def project_key(a)
    a = a.downcase

    if a[0..4] == 'home:'
      a = 'zz' + a
    end
    return a
  end
  private :project_key

  def get_filtered_projectlist(filterstring, excludefilter='', opts={})
    opts = {:only_incidents => false}.merge(opts)
    # remove illegal xpath characters
    filterstring.gsub!(/[\[\]\n]/, '')
    filterstring.gsub!(/[']/, '&apos;')
    filterstring.gsub!(/["]/, '&quot;')
    predicate = filterstring.empty? ? '' : "starts-with(@name, '#{filterstring}')"
    predicate += " and " if !predicate.empty? and !excludefilter.blank?
    predicate += "not(starts-with(@name,'#{excludefilter}'))" if !excludefilter.blank?
    predicate += " and " if !predicate.empty?
    if opts[:only_incidents]
      predicate += "@kind='maintenance_incident')"
    else
      predicate += "not(@kind='maintenance_incident')" # Filter all maintenance incidents
    end
    result = Collection.find(:id, :what => "project", :predicate => predicate)
    @projects = Array.new
    result.each { |p| @projects << p.name }
    @projects =  @projects.sort_by { |a| project_key a }
  end
  private :get_filtered_projectlist

  def users
    @users = @project.users
    @groups = @project.groups
    @roles = Role.local_roles
  end

  def subprojects
    @subprojects = Hash.new
    sub_names = Collection.find :id, :what => "project", :predicate => "starts-with(@name,'#{@project}:')"
    sub_names.each do |sub|
      @subprojects[sub.name] = find_cached( Project, sub.name )
    end
    @subprojects = @subprojects.sort # Sort by hash key for better display
    @parentprojects = Hash.new
    parent_names = @project.name.split ':'
    parent_names.each_with_index do |parent, idx|
      parent_name = parent_names.slice(0, idx+1).join(':')
      unless [@project.name, 'home'].include?( parent_name )
        parent_project = find_cached(Project, parent_name )
        @parentprojects[parent_name] = parent_project unless parent_project.blank?
      end
    end
    @parentprojects = @parentprojects.sort # Sort by hash key for better display
  end

  def attributes
    if @project.is_remote?
      @attributes = nil
    else
      @attributes = Attribute.find(:project => @project.name)
    end
  end

  def new
    @namespace = params[:ns]
    @project_name = params[:project]
    if @namespace
      begin
        @project = find_cached(Project, @namespace)
        if @namespace == "home:#{session[:login]}" and not @project
          @pagetitle = "Your home project doesn't exist yet. You can create it now"
          @project_name = @namespace
        end
      rescue
        flash[:error] = "Invalid namespace name '#{@namespace}'"
        redirect_back_or_to :controller => 'project', :action => 'list_public' and return
      end
    end
    if @project_name =~ /home:(.+)/
      @project_title = "#$1's Home Project"
    else
      @project_title = ""
    end
  end

  def new_incident
    required_parameters :ns
    target_project = ''
    begin
      path = "/source/#{CGI.escape(params[:ns])}/?cmd=createmaintenanceincident"
      result = ActiveXML::Node.new(frontend.transport.direct_http(URI(path), :method => "POST", :data => ""))
      result.each("/status/data[@name='targetproject']") { |n| target_project = n.text }
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
      redirect_to :action => 'show', :project => params[:ns] and return
    end
    flash[:success] = "Created maintenance incident project #{target_project}"
    redirect_to :action => 'show', :project => target_project and return
  end

  def new_package
  end

  def new_package_branch
  end

  def incident_request_dialog
    #TODO: Currently no way to find out where to send until the project 'maintained' relationship
    #      is really used. The API will find out magically here though.
    render_dialog
  end

  def new_incident_request
    begin
      req = BsRequest.new(:project => params[:project], :type => "maintenance_incident", :description => params[:description])
      req.save(create: true)
      flash[:success] = "Created maintenance release request"
    rescue ActiveXML::Transport::NotFoundError, ActiveXML::Transport::Error => e
      flash[:error] = e.summary
      redirect_back_or_to :action => 'show', :project => params[:project] and return
    end
    redirect_to :action => 'show', :project => params[:project]
  end

  def release_request_dialog
    render_dialog
  end

  def new_release_request
    if params[:skiprequest]
      # FIXME2.3: do it directly here, api function missing
    else
      begin
        req = BsRequest.new(:project => params[:project], :type => "maintenance_release", :description => params[:description])
        req.save(create: true)
        flash[:success] = "Created maintenance release request <a href='#{url_for(:controller => 'request', :action => 'show', :id => req.value("id"))}'>#{req.value("id")}</a>"
      rescue ActiveXML::Transport::NotFoundError => e
        flash[:error] = e.summary
        redirect_to(:action => 'show', :project => params[:project]) and return
      rescue ActiveXML::Transport::Error => e
        flash[:error] = e.summary
        redirect_back_or_to :action => 'show', :project => params[:project] and return
      end
    end
    redirect_to :action => 'show', :project => params[:project]
  end

  def load_project_info
    return unless check_valid_project_name
    begin
      @project_info = ApiDetails.find(:project_infos, :project => params[:project])
    rescue ActiveXML::Transport::NotFoundError
      return render_project_missing
    end
    @project = Project.new(@project_info["xml"])
    @packages = @project_info["packages"].map { |p| p[0] }.sort
    @open_maintenance_incidents = @project_info['incidents']
    @linking_projects = @project_info['linking_projects']
    @requests = @project_info['requests']
    @nr_of_problem_packages = @project_info['nr_of_problem_packages']

    # Is this a maintenance master project ?
    @is_maintenance_project = @project.project_type == "maintenance"
    @is_incident_project = @project.project_type == 'maintenance_incident'

    @maintained_projects = @project_info['maintained_projects']
    @open_release_requests = @project_info['open_release_requests']
  end

  def show
    required_parameters :project
    @bugowners_mail = []
    @project.bugowners.each do |bugowner|
      mail = bugowner.email
      @bugowners_mail.push(mail.to_s) if mail
    end unless @spider_bot

    @project_maintenance_project = @project_info['maintenance_project'] unless @spider_bot

    # An incident has a patchinfo if there is a package 'patchinfo' with file '_patchinfo', try to find that:
    @has_patchinfo = false
    @packages.each do |pkg_element|
      if pkg_element == 'patchinfo'
        Package.find_cached(pkg_element, :project => @project).files.each do |pkg_file|
          @has_patchinfo = true if pkg_file[:name] == '_patchinfo'
        end
      end
    end
    render :show, :status => params[:nextstatus] if params[:nextstatus]
  end

  def load_releasetargets
    @releasetargets = []
    @project.each_repository do |repo|
      @releasetargets.push(repo.releasetarget.value('project') + "/" + repo.releasetarget.value('repository')) if repo.has_element?('releasetarget')
    end
  end

  def linking_projects
    # TODO: remove this ajax call and replace it with a jquery dialog
    Rails.cache.delete("%s_linking_projects" % @project.name) if discard_cache?
    @linking_projects = Rails.cache.fetch("%s_linking_projects" % @project.name, :expires_in => 30.minutes) do
       @project.linking_projects
    end
    render_dialog
  end

  # TODO we need the architectures in api/distributions
  def add_repository_from_default_list
    @distributions = find_cached(Distribution, :all)
    if @distributions.all_vendors.length < 1
      if @user and @user.is_admin?      
        flash.now[:notice] = "There are no distributions configured! Check out <a href=\"/configuration/connect_instance\">Configuration > Interconnect</a>"
      else
        redirect_to :controller => 'project', :action => 'add_repository', :project => @project
      end
    end
  end

  def add_repository
    @torepository = params[:torepository]
  end


  def add_person
    @roles = Role.local_roles
  end

  def add_group
    @roles = Role.local_roles
  end

  def load_buildresult(cache = true)
    unless cache
      Buildresult.free_cache( :project => params[:project], :view => 'summary' )
    end
    unless @spider_bot
      @buildresult = find_cached(Buildresult, :project => params[:project], :view => 'summary', :expires_in => 3.minutes )
    end

    @repohash = Hash.new
    @statushash = Hash.new
    @repostatushash = Hash.new
    @packagenames = Array.new

    @buildresult.to_hash.elements("result") do |result|
      repo = result["repository"]
      arch = result["arch"]

      # repository status cache
      @repostatushash[repo] ||= Hash.new
      @repostatushash[repo][arch] = Hash.new

      if result.has_key? "state"
        if result.has_key? "dirty"
          @repostatushash[repo][arch] = "outdated_" + result["state"]
        else
          @repostatushash[repo][arch] = result["state"]
        end
      end
    end if @buildresult
    if @buildresult
      @buildresult = @buildresult.to_a
    else
      @buildresult = Array.new
    end
  end
  protected :load_buildresult

  def buildresult
    check_ajax
    load_buildresult false
    render :partial => 'buildstatus'
  end

  def delete_dialog
    @linking_projects = @project.linking_projects
    render_dialog
  end

  def delete
    begin
      if params[:force] == '1'
        @project.delete :force => 1
      else
        @project.delete
      end
      Rails.cache.delete("%s_packages_mainpage" % @project)
      Rails.cache.delete("%s_problem_packages" % @project)
      flash[:notice] = "Project '#{@project}' was removed successfully"
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
    end
    if not @project.project_type == 'maintenance'
      parent_projects = @project.parent_projects()
      if parent_projects and parent_projects.length > 1
        redirect_to :action => 'show', :project => parent_projects[parent_projects.length - 2][0]
      else
        redirect_to :action => 'list_public'
      end
    else
      redirect_to :action => 'show', :project => @project
    end
  end

  def repository_arch_list
    @repository_arch_list = Hash.new
    @project.each_repository do |repo|
      @repository_arch_list[repo.name] = repo.archs.sort.uniq
    end
    return @repository_arch_list
  end
  private :repository_arch_list

  def edit_repository
    check_ajax
    repo = @project.repository[params[:repository]]
    redirect_back_or_to(:controller => "project", :action => "repositories", :project => @project) and return if not repo
    # Merge project repo's arch list with currently available arches from API. This needed as you want
    # to keep currently non-working arches in the project meta.
    
    # Prepare a list of recommended architectures
    @recommended_arch_list = @available_architectures.each.map{|arch| arch.name if arch.recommended == "true"}

    @repository_arch_hash = Hash.new
    @available_architectures.each {|arch| @repository_arch_hash[arch.name] = false }
    repository_arch_list()[repo.name].each {|arch| @repository_arch_hash[arch] = true }

    render(:partial => 'edit_repository', :locals => {:repository => repo, :error => nil})
  end

  def update_target
    repo = @project.repository[params[:repo]]
    if params[:arch]
      repo.archs = params[:arch].keys
    else
      repo.archs = []
    end
    # Merge project repo's arch list with currently available arches from API. This needed as you want
    # to keep currently non-working arches in the project meta.
    @repository_arch_hash = Hash.new
    @available_architectures.each {|arch| @repository_arch_hash[arch.name] = false }
    repository_arch_list()[repo.name].each {|arch| @repository_arch_hash[arch] = true }
    begin
      @project.save
      render :partial => 'edit_repository', :locals => { :repository => repo, :has_data => true }
    rescue => e
      render :partial => 'edit_repository', :locals => { :repository => repo, :error => "#{e.summary}" }
    end
  end

  def repositories
    if @project.is_remote?
      # TODO support flagdetails for remote instances in the API
      flash[:error] = "You can't show repositories for remote instances"
      redirect_to :action => :show, :project => params[:project]
      return
    end
    # overwrite @project with different view
    # TODO to get this cached we need to make sure it gets purged on repo updates
    @project = Project.find( params[:project], :view => :flagdetails )
  end

  def repository_state
    # Get cycles of the repository build dependency information
    # 
    @repocycles = Hash.new
    @repositories = Array.new
    if params[:repository]
      @repositories << params[:repository]
    elsif @project.has_element? :repository
      @project.each_repository { |repository| @repositories << repository.name }
    end

    @project.each_repository do |repository| 
      next unless @repositories.include? repository.name
      @repocycles[repository.name] = Hash.new

      repository.each_arch do |arch|
        cycles = Array.new
        # skip all packages via package=- to speed up the api call, we only parse the cycles anyway
        deps = find_cached(BuilddepInfo, :project => @project.name, :package => "-", :repository => repository.name, :arch => arch)
        nr_cycles = 0
        if deps and deps.has_element? :cycle
          packages = Hash.new
          deps.each_cycle do |cycle|
            current_cycles = Array.new
            cycle.each_package do |p|
              p = p.text
              if packages.has_key? p
                current_cycles << packages[p]
              end
            end
            current_cycles.uniq!
            if current_cycles.empty?
              nr_cycles += 1
              nr_cycle = nr_cycles
            elsif current_cycles.length == 1
              nr_cycle = current_cycles[0]
            else
              logger.debug "HELP! #{current_cycles.inspect}"
            end
            cycle.each_package do |p|
              packages[p.text] = nr_cycle
            end
          end
        end
        cycles = Array.new
        1.upto(nr_cycles) do |i|
          list = Array.new
          packages.each do |package,cycle|
            list.push(package) if cycle == i
          end
          cycles << list.sort
        end
        @repocycles[repository.name][arch.text] = cycles unless cycles.empty?
      end
    end
  end

  def rebuild_time
    required_parameters :repository, :arch
    load_project_info
    @repository = params[:repository]
    @arch = params[:arch]
    @hosts = begin Integer(params[:hosts] || '40') rescue 40 end
    @scheduler = params[:scheduler] || 'needed'
    unless ["fifo", "lifo", "random", "btime", "needed", "neededb", "longest_data", "longested_triedread", "longest"].include? @scheduler
      flash[:error] = "Invalid scheduler type, check mkdiststats docu - aehm, source"
      redirect_to :action => :show, :project => @project
      return
    end
    bdep = find_cached(BuilddepInfo, :project => @project.name, :repository => @repository, :arch => @arch)
    jobs = find_cached(Jobhislist , :project => @project.name, :repository => @repository, :arch => @arch, 
            :limit => @packages.size * 3, :code => ['succeeded', 'unchanged'])
    unless bdep and jobs
      flash[:error] = "Could not collect infos about repository #{@repository}/#{@arch}"
      redirect_to :action => :show, :project => @project
      return
    end
    indir = Dir.mktmpdir 
    f = File.open(indir + "/_builddepinfo.xml", 'w')
    f.write(bdep.dump_xml) 
    f.close
    f = File.open(indir + "/_jobhistory.xml", 'w')
    f.write(jobs.dump_xml)
    f.close
    outdir = Dir.mktmpdir
    logger.debug "cd #{Rails.root.join('vendor', 'diststats').to_s} && perl ./mkdiststats --srcdir=#{indir} --destdir=#{outdir} 
             --outfmt=xml #{@project.name}/#{@repository}/#{@arch} --width=910
             --buildhosts=#{@hosts} --scheduler=#{@scheduler}"
    fork do
      Dir.chdir(Rails.root.join('vendor', 'diststats'))
      system("perl", "./mkdiststats", "--srcdir=#{indir}", "--destdir=#{outdir}", 
             "--outfmt=xml", "#{@project.name}/#{@repository}/#{@arch}", "--width=910",
             "--buildhosts=#{@hosts}", "--scheduler=#{@scheduler}")
    end
    Process.wait
    f=File.open(outdir + "/rebuild.png")
    png=f.read
    f.close 
    @pngkey = Digest::MD5.hexdigest( params.to_s )
    Rails.cache.write("rebuild-%s.png" % @pngkey, png)
    f=File.open(outdir + "/longest.xml")
    longest = ActiveXML::Node.new(f.read)
    @timings = Hash.new
    longest.timings.each_package do |p|
      @timings[p.value(:name)] = [p.value(:buildtime), p.value(:finished)]
    end
    @rebuildtime = Integer(longest.value :rebuildtime)
    f.close
    @longestpaths = Array.new
    longest.longestpath.each_path do |path|
      currentpath = Array.new
      path.each_package do |p|
        currentpath << p.text
      end
      @longestpaths << currentpath
    end
    # we append 4 empty paths, so there are always at least 4 in the array
    # to simplify the view code
    4.times { @longestpaths << Array.new }
    FileUtils.rm_rf indir
    FileUtils.rm_rf outdir
  end

  def rebuild_time_png
    required_parameters :key
    key = params[:key]
    png = Rails.cache.read("rebuild-%s.png" % key)
    headers['Content-Type'] = 'image/png'
    send_data(png, :type => 'image/png', :disposition => 'inline')
  end

  def packages
    headers["Status"] = "301 Moved Permanently"
    redirect_to :action => 'show', :project => @project
  end

  def requests
    @requests = ApiDetails.find(:project_requests, :project => @project.name)
    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]
  end

  def save_new
    if params[:name].blank? || !valid_project_name?( params[:name] )
      flash[:error] = "Invalid project name '#{params[:name]}'."
      redirect_to :action => "new", :ns => params[:ns] and return
    end

    project_name = params[:name].strip
    project_name = params[:ns].strip + ":" + project_name.strip if params[:ns]

    if Project.exists? project_name
      flash[:error] = "Project '#{project_name}' already exists."
      redirect_to :action => "new", :ns => params[:ns] and return
    end

    #store project
    @project = Project.new(:name => project_name)
    @project.title.text = params[:title]
    @project.description.text = params[:description]
    @project.set_project_type('maintenance') if params[:maintenance_project]
    @project.set_remoteurl(params[:remoteurl]) if params[:remoteurl]
    @project.add_person :userid => session[:login], :role => 'maintainer'
    @project.add_person :userid => session[:login], :role => 'bugowner'
    if params[:access_protection]
      @project.add_element "access"
      @project.access.add_element "disable"
    end
    if params[:source_protection]
      @project.add_element "sourceaccess"
      @project.sourceaccess.add_element "disable"
    end
    if params[:disable_publishing]
      @project.add_element "publish"
      @project.publish.add_element "disable"
    end
    begin
      if @project.save
        flash[:notice] = "Project '#{@project}' was created successfully"
        redirect_to :action => 'show', :project => project_name and return
      else
        flash[:error] = "Failed to save project '#{@project}'"
      end
    rescue ActiveXML::Transport::ForbiddenError
      flash[:error] = "You lack the permission to create the project '#{@project}'. " +
        "Please create it in your home:%s namespace" % session[:login]
      redirect_to :action => 'new', :ns => "home:" + session[:login] and return
    end
    redirect_to :action => 'new'
  end

  def save
    if ( !params[:title] )
      flash[:error] = "Title must not be empty"
      redirect_to :action => 'edit', :project => params[:project]
      return
    end

    @project.title.text = params[:title]
    @project.description.text = params[:description]

    if @project.save
      flash[:notice] = "Project '#{@project}' was saved successfully"
    else
      flash[:error] = "Failed to save project '#{@project}'"
    end

    redirect_to :action => :show, :project => @project
  end

  def save_targets
    if params[:target_project].blank? and params[:torepository].blank? and
        params[:repo].blank? and params[:target_repo].blank?
      flash[:error] = "Missing arguments for target project or repository"
      redirect_to :action => "add_repository_from_default_list", :project => @project and return
    end
    target_repo = params[:target_repo]

    # extend an existing repository with a path
    if params.has_key?(:torepository)
      repo_path = "#{params[:target_project]}/#{target_repo}"
      if @project.add_path_to_repository(:reponame => params[:torepository], :repo_path => repo_path)
        @project.save
        flash[:success] = "Path #{params['target_project']}/#{target_repo} added successfully"
        redirect_to :action => 'repositories', :project => @project and return
      else
        flash[:error] = "Path #{params['target_project']}/#{target_repo} is already set for this repository"
        redirect_to :action => 'add_repository', :project => @project, :torepository => params[:torepository] and return
      end
    elsif params.has_key?(:repo)
      # add new repositories
      repos = params[:repo]
      # this interface is a mess
      if repos.kind_of? String
	repos=[repos]
      end
      repos.each do |repo|
        if !valid_target_name? repo
          flash[:error] = "Illegal target name #{repo}."
          redirect_to :action => :add_repository_from_default_list, :project => @project and return
        end
        repo_path = params[repo + '_repo'] || "#{params[:target_project]}/#{target_repo}"
        repo_archs = params[repo + '_arch'] || params[:arch]
        logger.debug "Adding repo: #{repo_path}, archs: #{repo_archs}"
        @project.add_repository(:reponame => repo, :repo_path => repo_path, :arch => repo_archs)

        # FIXME: will be cleaned up after implementing FATE #308899
        if repo == "images"
          prjconf = frontend.get_source(:project => params[:project], :filename => '_config')
          unless prjconf =~ /^Type:/
            prjconf = "%if \"%_repository\" == \"images\"\nType: kiwi\nRepotype: none\nPatterntype: none\n%endif\n" << prjconf
            frontend.put_file(prjconf, :project => @project, :filename => '_config')
          end
        end
      end

      @project.save
      flash[:success] = "Build targets were added successfully"
      redirect_to :action => 'repositories', :project => @project and return
    end
  rescue ActiveXML::Transport::Error => e
    flash[:error] = "Failed to add project or repository: " + e.summary
    redirect_back_or_to :action => 'repositories', :project => @project and return
  end

  def remove_target_request_dialog
    @project = params[:project]
    @repository = params[:repository]
    render_dialog
  end

  def remove_target_request
    begin
      req = BsRequest.new(:type => "delete", :targetproject => params[:project], :targetrepository => params[:repository], :description => params[:description])
      req.save(create: true)
      flash[:success] = "Created <a href='#{url_for(:controller => 'request', :action => 'show', :id => req.value("id"))}'>repository delete request #{req.value("id")}</a>"
    rescue ActiveXML::Transport::NotFoundError => e
      flash[:error] = e.summary
      redirect_to :action => :repositories, :project => @project and return
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
      redirect_back_or_to :action => :repositories, :project => @project and return
    end
    redirect_to :controller => :request, :action => :show, :id => req.value("id")
  end

  def remove_target
    if not params[:target]
      flash[:error] = "Target removal failed, no target selected!"
      redirect_to :action => :show, :project => params[:project]
    end
    @project.remove_repository params[:target]
    begin
      if @project.save
        flash[:notice] = "Target '#{params[:target]}' was removed"
      else
        flash[:error] = "Failed to remove target '#{params[:target]}'"
      end
    rescue ActiveXML::Transport::Error => e
      flash[:error] = "Failed to remove target '#{params[:target]}' " + e.summary
    end
    redirect_to :action => :repositories, :project => @project
  end

  def remove_path_from_target
    required_parameters :repository, :path_project, :path_repository
    @project.remove_path_from_target( params[:repository], params[:path_project], params[:path_repository] )
    @project.save
    flash[:success] = "Removed path #{params['path_project']}/#{params['path_repository']} from #{params['repository']}"
    redirect_to :action => :repositories, :project => @project
  end

  def move_path_up
    required_parameters :repository, :path_project, :path_repository
    @project.repository[params[:repository]].move_path(params[:path_project] + '/' + params[:path_repository], :up)
    @project.save
    redirect_to :action => :repositories, :project => @project
  end

  def move_path_down
    required_parameters :repository, :path_project, :path_repository
    @project.repository[params[:repository]].move_path(params[:path_project] + '/' + params[:path_repository], :down)
    @project.save
    redirect_to :action => :repositories, :project => @project
  end

  def change_role_options(params, action)
    ret = { project: @project.name, todo: action }
    ret[:role] = params[:role] if params.has_key? :role
    if params.has_key? :userid
      return ret.merge( { userid: params[:userid] })
    else
      return ret.merge( { groupid: params[:groupid] })
    end
  end

  def save_person
    begin
      ApiDetails.command(:change_role, change_role_options(params, 'add'))
      @project.free_cache
    rescue ApiDetails::CommandFailed => e
      flash[:error] = e.to_s
      redirect_to action: :add_person, project: @project, role: params[:role], userid: params[:userid]
      return
    end
    respond_to do |format|
      format.js { render json: 'ok' }
      format.html do
        flash[:notice] = "Added user #{params[:userid]} with role #{params[:role]}"
        redirect_to action: :users, project: @project
      end
    end
  end

  def save_group
    begin
      ApiDetails.command(:change_role, change_role_options(params, 'add'))
      @project.free_cache
    rescue ApiDetails::CommandFailed => e
      flash[:error] = e.to_s
      redirect_to action: :add_group, project: @project, role: params[:role], groupid: params[:groupid]
      return
    end
    respond_to do |format|
      format.js { render json: 'ok' }
      format.html do
        flash[:notice] = "Added group #{params[:groupid]} with role #{params[:role]} to project #{@project}"
        redirect_to action: :users, project: @project
      end
    end
  end

  def remove_role
    begin
      ApiDetails.command(:change_role, change_role_options(params, 'remove'))
      @project.free_cache
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
    end
    respond_to do |format|
      format.js { render json: 'ok' }
      format.html do
        if params[:userid]
          flash[:notice] = "Removed user #{params[:userid]}"
        else
          flash[:notice] = "Removed group '#{params[:groupid]}'"
        end
        redirect_to action: :users, project: @project
      end
    end
  end

  def monitor
    @name_filter = params[:pkgname]
    @lastbuild_switch = params[:lastbuild]
    if params[:defaults]
      defaults = (Integer(params[:defaults]) rescue 1) > 0
    else
      defaults = true
    end
    params['expansionerror'] = 1 if params['unresolvable']
    @avail_status_values = Buildresult.avail_status_values
    @filter_out = ['disabled', 'excluded', 'unknown']
    @status_filter = []
    @avail_status_values.each { |s|
      id=s.gsub(' ', '')
      if params.has_key?(id)
        next unless (Integer(params[id]) rescue 1) > 0
      else
        next unless defaults
      end
      next if defaults && @filter_out.include?(s)
      @status_filter << s
    }

    @avail_arch_values = []
    @avail_repo_values = []

    @project.to_hash.elements("repository") { |r|
      @avail_repo_values << r["name"]
      @avail_arch_values << r.elements("arch")
    }
    @avail_arch_values = @avail_arch_values.flatten.uniq.sort
    @avail_repo_values = @avail_repo_values.flatten.uniq.sort

    @arch_filter = []
    @avail_arch_values.each { |s|
      archid = valid_xml_id('arch_' + s)
      if defaults || (params.has_key?(archid) && params[archid])
        @arch_filter << s
      end
    }

    @repo_filter = []
    @avail_repo_values.each { |s|
      repoid = valid_xml_id('repo_' + s)
      if defaults || (params.has_key?(repoid) && params[repoid])
        @repo_filter << s
      end
    }

    find_opt = { :project => @project, :view => 'status', :code => @status_filter,
      :arch => @arch_filter, :repo => @repo_filter }
    find_opt[:lastbuild] = 1 unless @lastbuild_switch.blank?

    @buildresult = Buildresult.find( find_opt )
    unless @buildresult
      flash[:error] = "No build results for project '#{@project}'"
      redirect_to :action => :show, :project => params[:project]
      return
    end

    @buildresult = @buildresult.to_hash
    if not @buildresult.has_key? "result"
      @buildresult_unavailable = true
      return
    end

    @repohash = Hash.new
    @statushash = Hash.new
    @repostatushash = Hash.new
    @packagenames = Array.new

    @buildresult.elements("result") do |result|
      @resultvalue = result
      repo = result["repository"]
      arch = result["arch"]

      next unless @repo_filter.include? repo
      @repohash[repo] ||= Array.new
      next unless @arch_filter.include? arch
      @repohash[repo] << arch

      # package status cache
      @statushash[repo] ||= Hash.new

      stathash = Hash.new
      result.elements("status") do |status|
        stathash[status["package"]] = status
      end
      stathash.keys.each do |p|
        @packagenames << p.to_s
      end

      @statushash[repo][arch] = stathash

      # repository status cache
      @repostatushash[repo] ||= Hash.new
      @repostatushash[repo][arch] = Hash.new

      if result.has_key? "state"
        if result.has_key? "dirty"
          @repostatushash[repo][arch] = "outdated_" + result["state"]
        else
          @repostatushash[repo][arch] = result["state"]
        end
      end
    end
    logger.debug @packagenames.inspect
    @packagenames = @packagenames.flatten.uniq.sort

    ## Filter for PackageNames ####
    @packagenames.reject! {|name| not filter_matches?(name,@name_filter) } if not @name_filter.blank?
    packagename_hash = Hash.new
    @packagenames.each { |p| packagename_hash[p.to_s] = 1 }

    # filter out repos without current packages
    @statushash.each do |repo, hash|
      hash.each do |arch, packages|

        has_packages = false
        packages.each do |p, status|
          if packagename_hash.has_key? p
            has_packages = true
            break
          end
        end
        unless has_packages
          @repohash[repo].delete arch
        end
      end
    end
  end

  def filter_matches?(input,filter_string)
    result = false
    filter_string.gsub!(/\s*/,'')
    filter_string.split(',').each { |filter|
      no_invert = filter.match(/(^!?)(.+)/)
      if no_invert[1] == '!'
        result = input.include?(no_invert[2]) ? result : true
      else
        result = input.include?(no_invert[2]) ? true : result
      end
    }
    return result
  end

  # should be in the package controller, but all the helper functions to render the result of a build are in the project
  def package_buildresult
    check_ajax
    @project = params[:project]
    @package = params[:package]
    begin
      @buildresult = find_hashed(Buildresult, :project => params[:project], :package => params[:package], :view => 'status', :lastbuild => 1, :expires_in => 2.minutes )
    rescue ActiveXML::Transport::Error # wild work around for backend bug (sends 400 for 'not found')
    end
    @repohash = Hash.new
    @statushash = Hash.new

    @buildresult.elements("result") do |result|
      repo = result["repository"]
      arch = result["arch"]

      @repohash[repo] ||= Array.new
      @repohash[repo] << arch

      # package status cache
      @statushash[repo] ||= Hash.new
      @statushash[repo][arch] = Hash.new

      stathash = @statushash[repo][arch]
      result.elements("status") do |status|
        stathash[status["package"]] = status
      end
    end if @buildresult
    render :layout => false
  end

  def toggle_watch
    if @user.watches? @project.name
      logger.debug "Remove #{@project} from watchlist for #{@user}"
      @user.remove_watched_project @project.name
    else
      logger.debug "Add #{@project} to watchlist for #{@user}"
      @user.add_watched_project @project.name
    end
    @user.save

    if request.env["HTTP_REFERER"]
      redirect_to :back
    else
      redirect_to :action => :show, :project => @project
    end
  end

  def meta
    begin
      @meta = frontend.get_source(:project => params[:project], :filename => '_meta')
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Project _meta not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public", :nextstatus => 404
    end
  end

  def save_meta
    begin
      frontend.put_file(params[:meta], :project => params[:project], :filename => '_meta')
    rescue ActiveXML::Transport::Error => e
      render :text => e.summary, :status => 400, :content_type => "text/plain"
      return
    end

    Project.free_cache params[:project]
    render :text => "Config successfully saved", :content_type => "text/plain"
  end

  def prjconf
    begin
      @config = frontend.get_source(:project => params[:project], :filename => '_config')
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Project _config not found: #{params[:project]}"
      redirect_to :controller => 'project', :action => 'list_public', :nextstatus => 404 and return
    end
  end

  def save_prjconf
    check_ajax
    frontend.put_file(params[:config], :project => params[:project], :filename => '_config')
    flash[:notice] = "Project Config successfully saved"
    render text: "Config successfully saved", content_type: "text/plain"
  end

  def change_flag
    check_ajax
    required_parameters :cmd, :flag
    frontend.source_cmd params[:cmd], :project => @project, :repository => params[:repository], :arch => params[:arch], :flag => params[:flag], :status => params[:status]
    @project = Project.find( :name => params[:project], :view => :flagdetails )
  end

  def clear_failed_comment
    # TODO(Jan): put this logic in the Attribute model
    transport ||= ActiveXML::transport
    params["package"].to_a.each do |p|
      begin
        transport.direct_http URI("/source/#{params[:project]}/#{p}/_attribute/OBS:ProjectStatusPackageFailComment"), :method => "DELETE"
      rescue ActiveXML::Transport::ForbiddenError => e
        flash[:error] = e.summary
        redirect_to :action => :status, :project => params[:project]
        return
      end
    end
    if request.xhr?
      render :text => '<em>Cleared comment</em>'
      return
    end
    if params["package"].to_a.length > 1
      flash[:notice] = "Cleared comment for packages %s" % params[:package].to_a.join(',')
    else
      flash[:notice] = "Cleared comment for package #{params[:package]}"
    end
    redirect_to :action => :status, :project => params[:project]
  end

  def edit
  end

  def edit_comment_form
    check_ajax
    @comment = params[:comment]
    @project = params[:project]
    @package = params[:package]
    @update = params[:update]
  end

  def edit_comment
    @package = params[:package]
    attr = Attribute.new(:project => params[:project], :package => params[:package])
    attr.set('OBS', 'ProjectStatusPackageFailComment', params[:text])
    begin
      attr.save
      @comment = params[:text]
    rescue ActiveXML::Transport::Error => e
      @comment = params[:last_comment]
      @error = e.message
    end
    @update = params[:update]
  end

  def status_filter_user(project, package, filter_for_user, project_maintainer_cache)
     return nil if filter_for_user.nil?
     if package['persons']
       # if the package has specific maintainer, we ignore project maintainers
       founduser = nil
       #logger.debug "filter #{package.inspect}"
       package['persons'].elements("person") do |u|
         if u['userid'] == filter_for_user.login and u['role'] == 'maintainer'
           founduser = true
         end
       end
       return true if founduser.nil?
     else
       unless project_maintainer_cache.has_key? project
         devel_project = find_cached(Project, project)
         project_maintainer_cache[project] = devel_project.is_maintainer? filter_for_user
       end
       return true unless project_maintainer_cache[project]
     end
     return nil
  end
  private :status_filter_user

  def status
    status = Rails.cache.fetch("status_%s" % @project, :expires_in => 10.minutes) do
      ProjectStatus.find(:project => @project).to_hash
    end

    all_packages = "All Packages"
    no_project = "No Project"
    @current_develproject = params[:filter_devel] || all_packages
    @ignore_pending = params[:ignore_pending] || false
    @limit_to_fails = !(!params[:limit_to_fails].nil? && params[:limit_to_fails] == 'false')
    @limit_to_old = !(params[:limit_to_old].nil? || params[:limit_to_old] == 'false')
    @include_versions = !(!params[:include_versions].nil? && params[:include_versions] == 'false')
    filter_for_user = Person.find(params[:filter_for_user]) unless params[:filter_for_user].blank?
    
    attributes = find_hashed(PackageAttribute, :namespace => 'OBS', 
      :name => 'ProjectStatusPackageFailComment', :project => @project, :expires_in => 2.minutes) 
    comments = Hash.new
    attributes.get("project").elements("package") do |p|
      p.elements("values") do |v|
        comments[p["name"]] = v["value"]
      end
    end if attributes

    upstream_versions = Hash.new
    upstream_urls = Hash.new

    if @include_versions || @limit_to_old
      attributes = find_hashed(PackageAttribute, :namespace => 'openSUSE',
        :name => 'UpstreamVersion', :project => @project, :expires_in => 20.minutes)
      attributes.get("project").elements("package") do |p|
        p.elements("values") {|v| upstream_versions[p["name"]] = v["value"] }
      end if attributes

      attributes = find_hashed(PackageAttribute, :namespace => 'openSUSE',
        :name => 'UpstreamTarballURL', :project => @project, :expires_in => 20.minutes)
      attributes.get("project").elements("package") do |p|
        p.elements("values") {|v| upstream_urls[p["name"]] = v["value"] }
      end if attributes
    end

    raw_requests = find_hashed(Collection,
      :what => 'request', :predicate => "(state/@name='new' or state/@name='review')", :expires_in => 5.minutes)

    @requests = Hash.new
    submits = Hash.new
    raw_requests.elements("request") do |r|
      id = r['id'].to_i
      @requests[id] = r
      r.elements('action') do |action|
        next unless action['type'] == "submit"
        target = action['target']
        key = target['project'] + "/" + target['package']
        submits[key] ||= Array.new
        submits[key] << id
      end
    end

    declines = Hash.new
    declined_requests = Rails.cache.fetch("declined_requests_#{@project.name}", :expires_in => 10.minutes) do
      ret = []
      BsRequest.list({:states => 'declined', :roles => "target", :project => @project.name}).each do |r|
        ret << r.to_hash
      end 
      ret
    end
    declined_requests.each do |r|
      id = r['id'].to_i
      @requests[id] = r
      r.elements('action') do |action|
        next unless action['type'] == 'submit'
        target = action['target']
        source = action['source']
        key = target['package']
        unless declines[key] && declines[key][:id] > id
          declines[key] = {
            :id => id, 
            :project => source['project'], 
            :package => source['package'], 
            :rev => source['rev'] }
        end
      end
    end
    
    #logger.debug declines.inspect

    @develprojects = Hash.new
    project_maintainer_cache = Hash.new

    @packages = Array.new
    status.elements("package") do |p|
      currentpack = Hash.new
      pname = p["name"]
      #next unless pname =~ %r{mkv.*}
      currentpack['name'] = pname
      currentpack['failedcomment'] = comments[pname] if comments.has_key? pname

      newest = 0
      p.elements("failure") do |f|
        next if f['repo'] =~ /snapshot/
        ftime = Integer(f['time']) rescue 0
        next if newest > ftime
        next if f['srcmd5'] != p['srcmd5']
        currentpack['failedarch'] = f['repo'].split('/')[1]
        currentpack['failedrepo'] = f['repo'].split('/')[0]
        newest = ftime
        currentpack['firstfail'] = newest
      end

      currentpack['problems'] = Array.new
      currentpack['requests_from'] = Array.new
      currentpack['requests_to'] = Array.new

      key = @project.name + "/" + pname
      if submits.has_key? key
        currentpack['requests_from'].concat(submits[key])
      end

      currentpack['version'] = p["version"]
      if upstream_versions.has_key? pname
        upstream_version = upstream_versions[pname]
        begin
          gup = Gem::Version.new(p["version"])
          guv = Gem::Version.new(upstream_version)
        rescue ArgumentError
          # if one of the versions can't be parsed we simply can't say
        end

        if gup && guv && gup < guv
          currentpack['upstream_version'] = upstream_version
          currentpack['upstream_url'] = upstream_urls[pname] if upstream_urls.has_key? pname
        end
      end

      currentpack['md5'] = p['verifymd5']
      currentpack['md5'] ||= p['srcmd5']

      currentpack['changesmd5'] = p.value 'changesmd5'

      if p['develpack']
        dproject = p['develpack']['proj']
        @develprojects[dproject] = 1
        currentpack['develproject'] = dproject
        if (@current_develproject != dproject or @current_develproject == no_project) and @current_develproject != all_packages
          next
        end
        currentpack['develpackage'] = p['develpack']['pack']
        key = "%s/%s" % [dproject, p['develpack']['pack']]
        if submits.has_key? key
          currentpack['requests_to'].concat(submits[key])
        end
        dp = p['develpack']['package']
        if dp
          currentpack['develmd5'] = dp['verifymd5']
          currentpack['develmd5'] ||= dp["srcmd5"]
          currentpack['develchangesmd5'] = dp['changesmd5']
          currentpack['develmtime'] = dp['maxmtime']

          if dp['error']
             currentpack['problems'] << 'error-' + dp['error']
          end

          newest = 0
          dp.elements("failure") do |f|
            ftime = Integer(f['time']) rescue 0
            next if newest > ftime
            next if f['srcmd5'] != dp['srcmd5']
            frepo = f['repo']
            currentpack['develfailedarch'] = frepo.split('/')[1]
            currentpack['develfailedrepo'] = frepo.split('/')[0]
            newest = ftime
            currentpack['develfirstfail'] = newest
          end

          next if status_filter_user(dproject, dp, filter_for_user, project_maintainer_cache)
        end

        if currentpack['md5'] && currentpack['develmd5'] && currentpack['md5'] != currentpack['develmd5']
          if declines[pname] && 
              declines[pname][:project] == dp.value(:project) &&
              declines[pname][:package] == dp.value(:name)
            
            sourcerev = Package.current_rev(dp.value(:project), dp.value(:name))
            if sourcerev == declines[pname][:rev]
              currentpack['currently_declined'] = declines[pname][:id]
              currentpack['problems'] << 'currently_declined'
            else
              currentpack['declined_request'] = declines[pname]
            end
          end
          if currentpack['currently_declined'].nil?
            if currentpack['changesmd5'] != currentpack['develchangesmd5']
              currentpack['problems'] << 'different_changes'
            else
              currentpack['problems'] << 'different_sources'
            end
          end
        end
      elsif @current_develproject != no_project
        next if status_filter_user(@project.name, p, filter_for_user, project_maintainer_cache)
        next if @current_develproject != all_packages
      end

      if p.has_key? 'link'
        plink = p['link']
        if currentpack['md5'] != plink['targetmd5']
          currentpack['problems'] << 'diff_against_link'
          currentpack['lproject'] = plink['project']
          currentpack['lpackage'] = plink['package']
        end
      end

      next if !currentpack['requests_from'].empty? && @ignore_pending
      if @limit_to_fails
        next if !currentpack['firstfail']
      else
        next unless (currentpack['firstfail'] or currentpack['failedcomment'] or currentpack['upstream_version'] or
            !currentpack['problems'].empty? or !currentpack['requests_from'].empty? or !currentpack['requests_to'].empty?)
        if @limit_to_old
          next if (currentpack['firstfail'] or currentpack['failedcomment'] or
            !currentpack['problems'].empty? or !currentpack['requests_from'].empty? or !currentpack['requests_to'].empty?)
        end
      end
      #currentpack['thefullthing'] = p
      @packages << currentpack
    end

    @develprojects = @develprojects.keys.sort { |x,y| x.downcase <=> y.downcase }
    @develprojects.insert(0, all_packages)
    @develprojects.insert(1, no_project)

    @packages.sort! { |x,y| x['name'] <=> y['name'] }

    respond_to do |format|
      format.json {
        render :text => JSON.pretty_generate(@packages), :layout => false, :content_type => "text/plain"
      } 
      format.html 
    end
  end

  def maintained_projects
    @maintained_projects = []
    @project.each("maintenance/maintains") do |maintained_project_name|
       @maintained_projects << maintained_project_name.value(:project)
    end
    redirect_back_or_to :action => 'show', :project => @project and return unless @is_maintenance_project
  end

  def add_maintained_project_dialog
    redirect_back_or_to :action => 'show', :project => @project and return unless @is_maintenance_project
    render_dialog
  end

  def add_maintained_project
    redirect_back_or_to :action => 'show', :project => @project and return unless @is_maintenance_project
    if params[:maintained_project].nil? or params[:maintained_project].empty?
      flash[:error] = 'Please provide a valid project name'
      redirect_back_or_to(:action => 'maintained_projects', :project => @project) and return
    end

    begin
      @project.add_maintained_project(params[:maintained_project])
      @project.save
      flash[:notice] = "Added project '#{params[:maintained_project]}' to maintenance"
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Failed to add project '#{params[:maintained_project]}' to maintenance"
    end
    redirect_to(:action => 'maintained_projects', :project => @project) and return
  end

  def remove_maintained_project
    redirect_back_or_to :action => 'show', :project => @project and return unless @is_maintenance_project
    if params[:maintained_project].nil? or params[:maintained_project].empty?
      flash[:error] = 'Please provide a valid project name'
      redirect_back_or_to(:action => 'maintained_projects', :project => @project) and return
    end

    @project.remove_maintained_project(params[:maintained_project])
    if @project.save
      flash[:notice] = "Removed project '#{params[:maintained_project]}' from maintenance"
    else
      flash[:error] = "Failed to remove project '#{params[:maintained_project]}' from maintenance"
    end
    redirect_to(:action => 'maintained_projects', :project => @project) and return
  end

  def maintenance_incidents
    if @spider_bot
      @incidents = []
    else
      @incidents = @project.maintenance_incidents(params[:type] || 'open')
    end
  end

  def list_incidents
    check_ajax
    lockout_spiders
    incidents = @project.maintenance_incidents(params[:type] || 'open', params.slice(:limit, :offset))
    if params[:append]
      render :partial => 'shared/incident_table_entries', :locals => { :incidents => incidents }
    else
      render :partial => 'shared/incident_table', :locals => { :incidents => incidents }
    end
  end

  def unlock_dialog
    render_dialog
  end

  def unlock
    begin
      path = "/source/#{CGI.escape(params[:project])}/?cmd=unlock&comment=#{CGI.escape(params[:comment])}"
      frontend.transport.direct_http(URI(path), :method => "POST", :data => '')
      flash[:success] = "Unlocked project #{params[:project]}"
      Project.free_cache(params[:project])
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
    end
    redirect_to :action => 'show', :project => params[:project] and return
  end

  private

  def filter_packages( project, filterstring )
    result = Collection.find :id, :what => "package",
      :predicate => "@project='#{project}' and contains(@name,'#{filterstring}')"
    return result.each.map {|x| x.name}
  end

  def check_valid_project_name
    required_parameters :project
    if !valid_project_name? params[:project]
      unless request.xhr?
        flash[:error] = "#{params[:project]} is not a valid project name"
        redirect_to :controller => "project", :action => "list_public", :nextstatus => 404 and return false
      else
        render :text => 'Not a valid project name', :status => 404 and return false
      end
    end
    return true
  end

  def render_project_missing
    if @user and params[:project] == "home:#{@user}"
      # checks if the user is registered yet
      flash[:notice] = "Your home project doesn't exist yet. You can create it now by entering some" +
        " descriptive data and press the 'Create Project' button."
      redirect_to :action => :new, :ns => "home:" + session[:login] and return
    end
    # remove automatically if a user watches a removed project
    if @user and @user.watches? params[:project]
      @user.remove_watched_project params[:project] and @user.save
    end
    unless request.xhr?
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public", :nextstatus => 404 and return
    else
      render :text => "Project not found: #{params[:project]}", :status => 404 and return
    end
  end

  def require_project
    return unless check_valid_project_name
    @project ||= find_cached(Project, params[:project], :expires_in => 5.minutes )
    unless @project
      return render_project_missing
    end
    # Is this a maintenance master project ?
    @is_maintenance_project = @project.project_type == "maintenance"
  end

end
