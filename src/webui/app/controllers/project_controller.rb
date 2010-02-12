require 'project_status'
require 'collection'
require 'buildresult'
include ActionView::Helpers::UrlHelper

class ProjectController < ApplicationController

  class NoChangesError < Exception; end

  before_filter :require_project, :only => [:delete, :buildresult, :view, 
    :edit, :save, :add_target_simple, :save_target, :status, :prjconf,
    :remove_person, :save_person, :add_person, :remove_target, :toggle_watch, :list_packages,
    :update_target, :edit_target, :show, :monitor, :edit_prjconf, :list_requests,
    :meta, :edit_meta ]
  before_filter :require_prjconf, :only => [:edit_prjconf, :prjconf ]
  before_filter :require_meta, :only => [:edit_meta, :meta ]
  before_filter :load_current_requests, :only => [ :show, :list_requests ]


  def index
    redirect_to :action => 'list_public'
  end

  def list_all
    @important_projects = get_important_projects
    list :with_homes
  end

  def list_public
    @important_projects = get_important_projects
    list :without_homes
  end

  def list(mode=:without_homes)
    filterstring = params[:projectsearch] || params[:searchtext] || ''
    # remove illegal xpath characters
    filterstring.sub!(/[\[\]\n]/, '')
    filterstring.sub!(/[']/, '&apos;')
    filterstring.sub!(/["]/, '&quot;')
    if !filterstring.empty?
      predicate = "contains(@name, '#{filterstring}')"
    else
      predicate = ''
    end
    if mode==:without_homes
      predicate += " and " if !predicate.empty?
      predicate += "not(starts-with(@name,'home:'))"
    end
    result = Collection.find :id, :what => "project", :predicate => predicate
    @projects = result.each.sort {|a,b| a.name.downcase <=> b.name.downcase}
    if request.xhr?
      render :partial => 'search_project', :locals => {:project_list => @projects}
    else
      if @projects.length == 1
        redirect_to :action => 'show', :project => @projects.first
      end
    end
  end
  private :list

  def list_my
    @user ||= Person.find( :login => session[:login] )
    if @user.has_element? :watchlist
      #extract a list of project names and sort them case insensitive
      @watchlist = @user.watchlist.each_project.map {|p| p.name }.sort {|a,b| a.downcase <=> b.downcase }
    end

    @iprojects = @user.involved_projects.each.map {|x| x.name}.uniq.sort
    @ipackages = Hash.new
    pkglist = @user.involved_packages.each.reject {|x| @iprojects.include?(x.project)}
    pkglist.sort(&@user.method('packagesorter')).each do |pack|
      @ipackages[pack.project] ||= Array.new
      @ipackages[pack.project] << pack.name if !@ipackages[pack.project].include? pack.name
    end

  end


  def remove_watched_project
    project = params[:project]
    @user ||= Person.find( session[:login] )
    logger.debug "removing watched project '#{project}' from user '#@user'"
    @user.remove_watched_project project
    @user.save

    if @user.has_element? :watchlist
      @watchlist = @user.watchlist.each_project.map {|p| p.name }.sort {|a,b| a.downcase <=> b.downcase }
    end

    render :partial => 'watch_list'
  end

  def new
    @namespace = params[:ns]
    @project_name = params[:project]
    if params[:ns] == "home:#{session[:login]}"
      @project = Project.find params[:ns]
      unless @project
        flash[:note] = "Your home project doesn't exist yet. You can create it now by entering some" +
          " descriptive data and press the 'Create Project' button."
        redirect_to :action => :new, :project => params[:ns] and return
      end
    end
    if @project_name =~ /home:(.+)/
      @project_title = "#$1's Home Project"
    else
      @project_title = ""
    end
  end

  def show
    @email_hash = Hash.new
    @project.each_person do |person|
      @email_hash[person.userid.to_s] = Person.find_cached( person.userid ).email.to_s
    end
    @subprojects = Collection.find :id, :what => "project", :predicate => "starts-with(@name,'#{params[:project]}:')"
    @arch_list = arch_list
    @tags, @user_tags_array = get_tags(:project => params[:project], :package => params[:package], :user => session[:login])
    @rating = Rating.find( :project => params[:project] )
  end

  def buildresult
    @arch_list = arch_list
    @buildresult = Buildresult.find( :project => params[:project], :view => 'summary' )
    render :partial => 'inner_repo_table', :locals => {:has_data => true}
  end


  def delete
    valid_http_methods :post
    @confirmed = params[:confirmed]
    if @confirmed == "1"
      begin
        if params[:force] == "1"
          @project.delete :force => 1
        else
          @project.delete
        end
      rescue ActiveXML::Transport::Error => err
        @error, @code, @api_exception = ActiveXML::Transport.extract_error_message err
        logger.error "Could not delete project #{@project}: #{@error}"
      end
    end
  end

  def arch_list
    if @arch_list.nil?
      tmp = []
      @project.each_repository do |repo|
        tmp += repo.archs
      end
      @arch_list = tmp.sort.uniq
    end
    return @arch_list
  end

  def get_tags(params)
    user_tags = Tag.find(:project => params[:project], :user => params[:user])
    tags = Tag.find(:tags_by_object, :project => params[:project])
    user_tags_array = []
    user_tags.each_tag do |tag|
        user_tags_array << tag.name
    end
    return tags, user_tags_array
  end

  def view
    @packages = []
    Package.find( :all, :project => params[:project] ).each_entry do |package|
      @packages << package.name
    end

    @created_timestamp = LatestAdded.find( :specific,
      :project => @project ).project.created
    @updated_timestamp = LatestUpdated.find( :specific,
      :project => @project ).project.updated

    #@tags = Tag.find(:user => session[:login], :project => @project.name)

    #TODO not efficient, @user_tags_array is needed because of shared _tags_ajax.rhtml
    @tags, @user_tags_array = get_tags(:project => params[:project], :package => params[:package], :user => session[:login])

    @downloads = Downloadcounter.find( :project => @project )
    @rating = Rating.find( :project => @project )
    @activity = ( MostActive.find( :specific, :project => @project,
      :package => @package).project.activity.to_f * 100 ).round.to_f / 100
  end


  def show_projects_by_tag
    @collection = Collection.find(:tag, :type => "_projects", :tagname => params[:tag])
    @projects = []
    @collection.each_project do |project|
      @projects << project
    end
    @tagcloud ||= Tagcloud.new(:user => session[:login], :tagcloud => session[:tagcloud])
    render :action => "../tag/list_objects_by_tag"
  end


  def flags_for_experts
    @project = Project.find(params[:project])
    render :template => "flag/project_flags_for_experts"
  end

  #update project flags
  def update_flag
    begin
      #the flag matrix will also be initialized on access, so we can work on it
      @project = Project.find(params[:project])
      if @project.complex_flag_configuration? params[:flag_name]
        raise RuntimeError.new("Your flag configuration seems to be too complex to be saved through this interface. Please use OSC.")
      end

      @project.replace_flags(params)
    rescue RuntimeError => exception
      @error = exception
      logger.debug "[PROJECT:] Flag-Update-Error: flag configuration is rejected to be saved because of its complexity."
    rescue  ActiveXML::Transport::Error => exception
      #rescue_action_in_public exception
      @error = exception
      logger.debug "[PROJECT:] Error: #{@error}"
    end

    @flag = @project.send("#{params[:flag_name]}"+"flags")[params[:flag_id].to_sym]

  end

  def enable_arch
    @project = Project.find(params[:project])
    @arch_list = arch_list
    repo = @project.repository[params[:repo]]
    repo.add_arch params[:arch]
    if @project.save
      render :partial => 'repository_item', :locals => { :repo => repo, :has_data => true }
    else
      render :text => 'enabling architecture failed'
    end
  end

  def edit_target
    repo = @project.repository[params[:repo]]
    @arch_list = arch_list
    render :partial => 'repository_edit_form', :locals => { :repo => repo, :error => nil }
  end


  def update_target
    valid_http_methods :post
    repo = @project.repository[params[:repo]]
    repo.name = params[:name]
    repo.archs = params[:arch].to_a
    @arch_list = arch_list
    begin
      @project.save
      render :partial => 'repository_item', :locals => { :repo => repo, :has_data => true }
    rescue => e
      repo.name = params[:original_name]
      render :partial => 'repository_edit_form', :locals => { :error => "#{ActiveXML::Transport.extract_error_message( e )[0]}",
        :repo => repo } and return
    end
  end


  # render the input form for tags
  def add_tag_form
    @project = params[:project]
    render :partial => "add_tag_form"
  end


  def add_tag
    logger.debug "New tag(s) #{params[:tag]} for project #{params[:project]}."
    tags = []
    tags << params[:tag]
    old_tags = Tag.find(:user => session[:login], :project => params[:project])
    old_tags.each_tag do |tag|
      tags << tag.name
    end
    logger.debug "[TAG:] saving tags #{tags.join(" ")} for project #{params[:project]}."

    @tag_xml = Tag.new(:project => params[:project], :tag => tags.join(" "), :user => session[:login])
    begin
      @tag_xml.save

    rescue ActiveXML::Transport::Error => exception
      rescue_action_in_public exception
      @error = CGI::escapeHTML(@message)
      logger.debug "[TAG:] Error: #{@message}"
      @unsaved_tags = true
    end

    @tags, @user_tags_array = get_tags(:user => session[:login], :project => params[:project])

    render :update do |page|
      page.replace_html 'tag_area', :partial => "tags_ajax"
      page.visual_effect :highlight, 'tag_area'
      if @unsaved_tags
        page.replace_html 'error_message', "WARNING: #{@error}"
        page.show 'error_message'
        page.delay(30) do
          page.hide 'error_message'
        end
      end
    end
  end

  def list_packages
    @matching_packages = []
    Package.find( :all, :project => params[:project] ).each_entry do |package|
      @matching_packages << package.name
    end
    render :partial => "search_package"
  end

  def list_requests
  end

  def save_new
    @namespace = params[:ns]
    @project_title = params[:title]
    @project_description = params[:description]
    @new_project_name = params[:name]
    if params[:ns]
       project_name = params[:ns].strip + ":" + @new_project_name.strip
    else
       project_name = @new_project_name.strip
    end

    if !valid_project_name? project_name
      flash.now[:error] = "Invalid project name '#{project_name}'."
      render :action => "new" and return
    end

    if Project.exists? project_name
      flash.now[:error] = "Project '#{project_name}' already exists."
      render :action => "new" and return
    end

    Person.find( session[:login] )
    #store project
    @project = Project.new(:name => project_name)
    @project.title.text = params[:title]
    @project.description.text = params[:description]
    @project.add_person :userid => session[:login], :role => 'maintainer'
    @project.add_person :userid => session[:login], :role => 'bugowner'
    begin
      if @project.save
        flash[:note] = "Project '#{@project}' was created successfully"
        redirect_to :action => 'show', :project => project_name and return
      else
        flash[:error] = "Failed to save project '#{@project}'"
      end
    rescue ActiveXML::Transport::ForbiddenError => err
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
      flash[:note] = "Project '#{@project}' was saved successfully"
    else
      flash[:error] = "Failed to save project '#{@project}'"
    end

    redirect_to :action => :show, :project => @project
  end

  def add_repository
    @project = params[:project]
  end

  def receive_repository
    @id = params[:id]
  end

  def update_project_list
    if params[:filter]
      @project_list = Collection.find :id, :what => "project", :predicate => "contains(@name,'#{params[:filter]}')"
    else
      @project_list = Project.find :all
    end
    render :partial => "project_list"
      
  end

  def update_repolist
    logger.debug "updating repolist for project #{params[:project]}"
    project = Project.find params[:project]
    if project.has_element? :repository
      render :partial => "repository_list", :locals => {:project => params[:project], :repos => project.each_repository}
    else
      render :text => "<b>No repositories found</b>"
    end
  end


  def add_target
    @platforms = Platform.find( :all ).each_entry.map {|p| p.name.to_s}

    #TODO: don't hardcode
    @priority_namespaces = %{
      Mandriva
      openSUSE
      SUSE
      RedHat
      Fedora
      Debian
      Ubuntu
    }

    def @priority_namespaces.include_ns?(projname)
      nslist = projname.split(/:/)
      return false if nslist.length < 2
      return false unless self.include? nslist[0]
      return true
    end

    @platforms.sort! do |a,b|
      if @priority_namespaces.include_ns? a
        if @priority_namespaces.include_ns? b
          a.downcase <=> b.downcase
        else
          -1
        end
      else
        if @priority_namespaces.include_ns? b
          1
        else
          a.downcase <=> b.downcase
        end
      end
    end

    @project = params[:project]
    @targetname = params[:targetname]
    @platform = params[:platform]
  end

  def save_target
    platform = params[:platform]
    arch = params[:arch]
    targetname = params[:targetname]
    targetname = "standard" if targetname.blank?

    if !valid_platform_name? targetname
      flash[:error] = "Illegal target name."
      redirect_to :action => :add_target, :project => @project, :targetname => targetname, :platform => platform
      return
    end

# It is allowed to have no repository as base. kiwi packages specifies their own.
#    if platform.blank?
#      flash[:error] = "Please select a target platform."
#      redirect_to :action => :add_target, :project => @project, :targetname => targetname, :platform => platform
#      return
#    end

    @project.add_repository :reponame => targetname, :platform => platform, :arch => arch

    begin
      if @project.save
        flash[:note] = "Target '#{platform}' was added successfully"
      else
        flash[:error] = "Failed to add target '#{platform}'"
      end
    rescue ActiveXML::Transport::Error => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        flash[:error] = "Failed to add target '#{platform}' " + message
    end

    redirect_to :action => :show, :project => @project
  end

  def remove_target
    if not params[:target]
      flash[:error] = "Target removal failed, no target selected!"
      redirect_to :action => :show, :project => params[:project]
    end
    @project.remove_repository params[:target]

    begin
      if @project.save
        flash[:note] = "Target '#{params[:target]}' was removed"
      else
        flash[:error] = "Failed to remove target '#{params[:target]}'"
      end
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = "Failed to remove target '#{params[:target]}' " + message
    end

    redirect_to :action => :show, :project => @project
  end


  def save_person
    valid_http_methods(:post)
    if not valid_role_name? params[:userid]
      flash[:error] = "Invalid username: #{params[:userid]}"
      redirect_to :action => :add_person, :project => params[:project], :role => params[:role]
      return
    end
    user = Person.find( :login => params[:userid] )
    unless user
      flash[:error] = "Unknown user with id '#{params[:userid]}'"
      redirect_to :action => :add_person, :project => params[:project], :role => params[:role]
      return
    end
    logger.debug "found user: #{user.inspect}"
    @project.add_person( :userid => params[:userid], :role => params[:role] )

    if @project.save
      flash[:note] = "added user #{params[:userid]}"
    else
      flash[:error] = "Failed to add user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :project => @project
  end

  def remove_person
    if not params[:userid]
      flash[:note] = "User removal aborted, no user id given!"
      redirect_to :action => :show, :project => params[:project]
      return
    end
    @project.remove_persons( :userid => params[:userid], :role => params[:role] )

    if @project.save
      flash[:note] = "removed user #{params[:userid]}"
    else
      flash[:error] = "Failed to remove user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :project => params[:project]
  end

  def monitor
    @name_filter = params[:pkgname]
    @lastbuild_switch = params[:lastbuild]
    if params[:defaults]
      defaults = (Integer(params[:defaults]) rescue 1) > 0
    else
      defaults = true
    end
    @avail_status_values = 
      ['succeeded','failed','expansion error','broken', 
      'blocked', 'dispatching', 'scheduled','building','finished',
      'disabled', 'excluded','unknown']
    @status_filter = []
    @avail_status_values.each { |s|
      if defaults || (params.has_key?(s) && params[s])
        @status_filter << s
      end
    }
    
    @avail_arch_values = []
    @avail_repo_values = []

    @project.repositories.each { |r|
      @avail_repo_values << r.name
      @avail_arch_values << r.archs if r.archs
    }
    @avail_arch_values = @avail_arch_values.flatten.uniq.sort
    @avail_repo_values = @avail_repo_values.flatten.uniq.sort

    @arch_filter = []
    @avail_arch_values.each { |s|
      if defaults || (params.has_key?('arch_' + s) && params['arch_' + s])
        @arch_filter << s
      end
    }
   
    @repo_filter = []
    @avail_repo_values.each { |s|
      if defaults || (params.has_key?('repo_' + s) && params['repo_' + s])
        @repo_filter << s
      end
    }

    @buildresult = Buildresult.find( :project => @project, :view => 'status', :code => @status_filter,
                   @lastbuild_switch.blank? ? nil : :lastbuild => '1', :arch => @arch_filter, :repo => @repo_filter )
    unless @buildresult
      flash[:error] = "No build results for project '#{@project}'"
      redirect_to :action => :show, :project => params[:project]
      return
    end

    if not @buildresult.has_element? :result
      @buildresult_unavailable = true
      return
    end

    @repohash = Hash.new
    @statushash = Hash.new
    @repostatushash = Hash.new
    @packagenames = Array.new

    @buildresult.each_result do |result|
      @resultvalue = result
      repo = result.repository
      arch = result.arch

      next unless @repo_filter.include? repo
      @repohash[repo] ||= Array.new
      next unless @arch_filter.include? arch
      @repohash[repo] << arch

      # package status cache
      @statushash[repo] ||= Hash.new
      @statushash[repo][arch] = Hash.new

      stathash = @statushash[repo][arch]
      result.each_status do |status|
        stathash[status.package] = status
      end
      @packagenames << stathash.keys

      # repository status cache
      @repostatushash[repo] ||= Hash.new
      @repostatushash[repo][arch] = Hash.new

      if result.has_attribute? :state
        if result.has_attribute? :dirty
          @repostatushash[repo][arch] = "outdated(#{result.state})"
        else
          @repostatushash[repo][arch] = "#{result.state}"
        end
      end
    end
    @packagenames = @packagenames.flatten.uniq.sort

    ## Filter for PackageNames #### 
    @packagenames.reject! {|name| not filter_matches?(name,@name_filter) } if not @name_filter.blank?

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
    @project = params[:project]
    @package = params[:package]
    @buildresult = Buildresult.find_cached( :project => params[:project], :package => params[:package], :view => 'status', :lastbuild => 1, :expires_in => 2.minutes )
    @repohash = Hash.new
    @statushash = Hash.new

    return unless @buildresult
    @buildresult.each_result do |result|
      repo = result.repository
      arch = result.arch

      @repohash[repo] ||= Array.new
      @repohash[repo] << arch

      # package status cache
      @statushash[repo] ||= Hash.new
      @statushash[repo][arch] = Hash.new

      stathash = @statushash[repo][arch]
      result.each_status do |status|
        stathash[status.package] = status
      end
    end
  end

  def toggle_watch
    @user ||= Person.find( :login => session[:login] )
    if @user.watches? @project.name
      @user.remove_watched_project @project.name
    else
      @user.add_watched_project @project.name
    end
    @user.save
    render :partial => "watch_link"
  end


  def rate
    @project = params[:project]
    @score = params[:score] or return
    rating = Rating.new( :score => @score, :project => @project )
    rating.save
    @rating = Rating.find( :project => @project )
    render :partial => 'shared/rate'
  end

  def prjconf
  end
  
  def edit_prjconf
  end

  def save_prjconf
    frontend.put_file(params[:config], :project => params[:project], :filename => '_config')
    flash[:note] = "Project Config successfully saved"
    redirect_to :action => :prjconf, :project => params[:project]
  end

  def save_meta
    frontend.put_file(params[:meta], :project => params[:project], :filename => '_meta')
    flash[:note] = "Config successfully saved"
    redirect_to :action => :show, :project => params[:project]
  end

  def clear_failed_comment
    # TODO(Jan): put this logic in the Attribute model
    transport ||= ActiveXML::Config::transport_for(:package)
    params["package"].to_a.each do |p|
      begin
        transport.direct_http URI("/source/#{params[:project]}/#{p}/_attribute/OBS:ProjectStatusPackageFailComment"), :method => "DELETE"
      rescue ActiveXML::Transport::ForbiddenError => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        flash[:error] = message
        redirect_to :action => :status, :project => params[:project]
        return
      end
    end
    if params["package"].to_a.length > 1
      flash[:note] = "Cleared comment for packages %s" % params[:package].to_a.join(',')
    else
      flash[:note] = "Cleared comment for package #{params[:package]}"
    end
    redirect_to :action => :status, :project => params[:project]
  end

  def edit_comment_form
    @comment = params[:comment]
    @project = params[:project]
    @package = params[:package]
    render :partial => "edit_comment_form"
  end

  def edit_comment
    @project = params[:project]
    @package = params[:package]
    attr = Attribute.new(:project => params[:project], :package => params[:package])
    attr.set('OBS', 'ProjectStatusPackageFailComment', params[:text])
    result = attr.save
    @result = result
    if result[:type] == :error
      @comment = params[:last_comment]
    else
      @comment = params[:text]
    end
    render :partial => "edit_comment"
  end

  def get_changes_md5(project, package)
    dir = Directory.find_cached(:project => project, :package => package, :expand => "1")
    return nil unless dir
    changes = []
    dir.each_entry do |e|
      name = e.name.to_s
      if name =~ /.changes$/
        if name == package + ".changes"
          return e.md5.to_s
        end
        changes << e.md5.to_s
        puts e.inspect
      end
    end
    if changes.size == 1
      return changes[0]
    end
    logger.debug "can't find unique changes file: " + dir.dump_xml
    raise NoChangesError, "no .changes file in #{project}/#{package}"
  end
  private :get_changes_md5

  def changes_file_difference(project1, package1, project2, package2)
    md5_1 = get_changes_md5(project1, package1)
    md5_2 = get_changes_md5(project2, package2)
    return md5_1 != md5_2
  end
  private :changes_file_difference

  def status
    status = Rails.cache.fetch("status_%s" % @project, :expires_in => 10.minutes) do
      ProjectStatus.find(:project => @project)
    end

    all_packages = "All Packages" 
    no_project = "No Project"
    @current_develproject = params[:filter_devel] || all_packages
    @ignore_pending = params[:ignore_pending] || false
    @limit_to_fails = !(!params[:limit_to_fails].nil? && params[:limit_to_fails] == 'false')

    attributes = PackageAttribute.find(:namespace => 'OBS', 
      :name => 'ProjectStatusPackageFailComment', :project => @project, :expires_in => 2.minutes)
    comments = Hash.new
    attributes.data.find('//package//values').each do |p|
      # unfortunately libxml's find_first does not work on nodes, but on document (known bug)
      p.each_element do |v| 
        comments[p.parent['name']] = v.content
      end
    end

    attributes = PackageAttribute.find_cached(:namespace => 'openSUSE',
      :name => 'UpstreamVersion', :project => @project, :expires_in => 2.minutes)
    upstream_versions = Hash.new
    attributes.data.find('//package//values').each do |p|
      # unfortunately libxml's find_first does not work on nodes, but on document (known bug)
      p.each_element do |v|
        upstream_versions[p.parent['name']] = v.content
      end
    end

    attributes = PackageAttribute.find_cached(:namespace => 'openSUSE',
      :name => 'UpstreamTarballURL', :project => @project, :expires_in => 2.minutes)
    upstream_urls = Hash.new
    attributes.data.find('//package//values').each do |p|
      # unfortunately libxml's find_first does not work on nodes, but on document (known bug)
      p.each_element do |v|
        upstream_urls[p.parent['name']] = v.content
      end
    end

    raw_requests = Rails.cache.fetch("requests_new", :expires_in => 5.minutes) do
      Collection.find(:what => 'request', :predicate => "(state/@name='new')")
    end

    @requests = Hash.new
    submits = Hash.new
    raw_requests.each_request do |r|
      id = Integer(r.data['id'])
      @requests[id] = r
      #logger.debug r.dump_xml + " " + (r.has_element?('action') ? r.action.data['type'] : "false")
      if r.has_element?('action') && r.action.data['type'] == "submit"
        target = r.action.target.data
        key = target['project'] + "/" + target['package']
        submits[key] ||= Array.new
        submits[key] << id
      end
    end

    @develprojects = Array.new

    @packages = Array.new
    status.each_package do |p|
      currentpack = Hash.new
      currentpack['name'] = p.name
      currentpack['failedcomment'] = comments[p.name] if comments.has_key? p.name
      newest = 0

      p.each_failure do |f|
        next if f.repo =~ /ppc/
        next if f.repo =~ /staging/
        next if f.repo =~ /snapshot/
        next if newest > (Integer(f.time) rescue 0)
        next if f.srcmd5 != p.srcmd5
        currentpack['failedarch'] = f.repo.split('/')[1]
        currentpack['failedrepo'] = f.repo.split('/')[0]
        newest = Integer(f.time)
        currentpack['firstfail'] = newest
      end
      
      currentpack['problems'] = Array.new
      currentpack['requests_from'] = Array.new
      currentpack['requests_to'] = Array.new

      key = @project.name + "/" + p.name
      if submits.has_key? key
        currentpack['requests_from'].concat(submits[key])
      end

      currentpack['version'] = p.version
      if upstream_versions.has_key? p.name
        upstream_version = upstream_versions[p.name]
        if p.version < upstream_version
          currentpack['upstream_version'] = upstream_version
          currentpack['upstream_url'] = upstream_urls[p.name] if upstream_urls.has_key? p.name
        end
      end

      currentpack['md5'] = p.srcmd5

      if p.has_element? :develpack
        @develprojects << p.develpack.proj
        currentpack['develproject'] = p.develpack.proj
        if (@current_develproject != p.develpack.proj or @current_develproject == no_project) and @current_develproject != all_packages
          next
        end
        currentpack['develpackage'] = p.develpack.pack
        key = "%s/%s" % [p.develpack.proj, p.develpack.pack]
        if submits.has_key? key
          currentpack['requests_to'].concat(submits[key])
        end
        currentpack['develmd5'] = p.develpack.package.srcmd5

        if currentpack['md5'] and currentpack['develmd5'] and currentpack['md5'] != currentpack['develmd5']
          currentpack['problems'] << Rails.cache.fetch("dd_%s_%s" % [currentpack['md5'], currentpack['develmd5']]) do
             begin
               if changes_file_difference(@project.name, p.name, currentpack['develproject'], currentpack['develpackage'])
                 'different_changes'
               else
                 'different_sources'
               end
             rescue NoChangesError => e
               e.message
             end
          end
        end
      elsif @current_develproject != no_project
        next if @current_develproject != all_packages
      end

      next if !currentpack['requests_from'].empty? and @ignore_pending
      if @limit_to_fails
        next if !currentpack['firstfail']
      else
        next unless (currentpack['firstfail'] or currentpack['failedcomment'] or currentpack['upstream_version'] or
            !currentpack['problems'].empty? or !currentpack['requests_from'].empty? or !currentpack['requests_to'].empty?)
      end
      @packages << currentpack
    end

    @develprojects.sort! { |x,y| x.downcase <=> y.downcase }.uniq!
    @develprojects.insert(0, all_packages)
    @develprojects.insert(1, no_project)

    @packages.sort! { |x,y| x['name'] <=> y['name'] }
  end

  private

  def get_important_projects
    predicate = "[attribute/@name='OBS:VeryImportantProject']"
    return Collection.find_cached :id, :what => "project", :predicate => predicate
  end


  def paginate_collection(collection, options = {})
    options[:page] = options[:page] || params[:page] || 1
    default_options = {:per_page => 20, :page => 1}
    options = default_options.merge options

    pages = Paginator.new self, collection.size, options[:per_page], options[:page]
    first = pages.current.offset
    last = [first + options[:per_page], collection.size].min
    slice = collection[first...last]
    return [pages, slice]
  end

  def filter_packages( project, filterstring )
    result = Collection.find :id, :what => "package",
      :predicate => "@project='#{project}' and contains(@name,'#{filterstring}')"
    return result.each.map {|x| x.name}
  end


  def require_project
    if !valid_project_name? params[:project] 
      unless request.xhr?
        flash[:error] = "#{params[:project]} is not a valid project name"
        redirect_to :controller => "project", :action => "list_public" and return
      else
        render :text => 'Not a valid project name', :status => 404 and return
      end
    end
    @project = Project.find( params[:project] )
    unless @project
      if params[:project] == "home:" + session[:login]
        # checks if the user is registered yet
        Person.find( :login => session[:login] )
        flash[:note] = "Your home project doesn't exist yet. You can create it now by entering some" +
          " descriptive data and press the 'Create Project' button."
        redirect_to :action => :new, :project => "home:" + session[:login] and return
      end
      # remove automatically if a user watches a removed project
      @user ||= Person.find( :login => session[:login] )
      @user.remove_watched_project params[:project] and @user.save if @user.watches? params[:project]
      unless request.xhr?
        flash[:error] = "Project not found: #{params[:project]}"
        redirect_to :controller => "project", :action => "list_public" and return
      else
        render :text => "Project not found: #{params[:project]}", :status => 404 and return
      end
    end
  end


  def require_prjconf
    if !valid_project_name? params[:project]
      flash[:error] = "#{params[:project]} is not a valid project name"
      redirect_to :controller => "project", :action => "list_public"
      return
    end

    @project = params[:project]
    begin
      @config = frontend.get_source(:project => params[:project], :filename => '_config')
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Project not found: #{params[:project]}" 
      redirect_to :controller => "project", :action => "list_public"
    end
  end

  def require_meta
    begin
      @meta = frontend.get_source(:project => params[:project], :filename => '_meta')
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Project _meta not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
    end
  end

 def load_current_requests
    predicate = "state/@name='new' and action/target/@project='#{@project}'"
    @current_requests = Collection.find_cached :what => :request, :predicate => predicate, :expires_in => 5.minutes
  end

end
