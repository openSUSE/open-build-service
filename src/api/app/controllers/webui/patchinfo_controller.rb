class Webui::PatchinfoController < Webui::WebuiController
  include Webui::WebuiHelper
  include Webui::PackageHelper
  before_filter :require_all
  before_filter :get_binaries, :except => [:show, :delete]
  before_filter :require_exists, :except => [:new_patchinfo]

  def new_patchinfo
    unless User.current.can_create_package_in? @project.api_obj
      flash[:error] = 'No permission to create packages'
      redirect_to :controller => 'project', :action => 'show', project: @project and return
    end

    unless @project.api_obj.exists_package? 'patchinfo'
      unless Patchinfo.new.create_patchinfo(@project.name, nil)
        flash[:error] = 'Error creating patchinfo'
        redirect_to :controller => 'project', :action => 'show', project: @project and return
      end
    end
    @package = @project.api_obj.packages.find_by_name('patchinfo')
    @file = @package.patchinfo
    unless @file
      flash[:error] = "Patchinfo not found for #{params[:project]}"
      redirect_to :controller => 'package', :action => 'show', :project => @project, :package => @package and return
    end

    read_patchinfo
    @binaries.each do |bin|
      if @binarylist.match(bin)
        @binarylist.delete(bin)
      end
    end
  end

  def updatepatchinfo
    path = "/source/#{CGI.escape(params[:project])}/#{CGI.escape(params[:package])}?cmd=updatepatchinfo"
    frontend.transport.direct_http( URI(path), :method => 'POST')
    redirect_to :action => 'edit_patchinfo', :project => @project, :package => @package
  end

  def edit_patchinfo
    read_patchinfo
    @tracker = 'bnc'
    @binaries.each do |bin|
      if @binarylist.find(bin)
        @binarylist.delete(bin)
      end
    end
  end

  def show
    read_patchinfo
    @pkg_names = @project.api_obj.packages.pluck(:name)
    @pkg_names.delete('patchinfo')
    @packager = User.where(login: @packager).first
  end

  def read_patchinfo
    @binaries = Array.new
    @file.each(:binary) do |binaries|
        @binaries << binaries.text
      end
    @binary = []
    @packager = @file.value(:packager)
    @issues = []
    @file.each(:issue) do |a|
      if a.text == ''
        # old uploaded patchinfos could have broken tracker-names like "bnc " instead of "bnc". Catch these.
        begin
          get_issue_sum(a.value(:tracker), a.value(:id))
          a.text = @issuesum
        rescue ActiveXML::Transport::NotFoundError
          a.text = 'PLEASE CHECK THE FORMAT OF THE ISSUE'
        end
      end
      issue = Array.new
      issueid = a.value(:id)
      issueurl = IssueTracker.find_by_name(a.value(:tracker))
      if issueurl
        issueurl = issueurl.show_url.sub(/@@@/, issueid)
      else
        issueurl = ''
      end
      issue << a.value(:tracker)
      issue << issueid
      issue << issueurl
      issue << a.text
      @issues << issue
    end

    if params[:issue] == nil
      params[:issue] = Array.new
      params[:issue] << params[:issueid]
    end
    if params[:issueid] != nil
      params[:issue] << params[:issueid]
      @issues = params[:issue]
    end
    @category = @file.value(:category)
    @rating = @file.value(:rating)
    @category = @file.value(:category)
    @rating = @file.value(:rating)
    @summary = @file.value(:summary)
    
    @description = @file.value(:description)
    if @file.has_element?('relogin_needed')
      @relogin = true
    else
      @relogin = false
    end
    if @file.has_element?('reboot_needed')
      @reboot = true
    else
      @reboot = false
    end
    if @file.has_element?('zypp_restart_needed')
      @zypp_restart_needed = true
    else
      @zypp_restart_needed = false
    end
    if @file.has_element?('stopped')
      @block = true
      @block_reason = @file.value(:stopped)
    end
  end

  def save
    begin
      filename = '_patchinfo'
      valid_params = true
      required_parameters :project, :package
      flash[:error] = nil
      if !valid_summary? params[:summary]
        valid_params = false
        flash[:error] = "#{flash[:error]}" + ' || Summary is too short (should have more than 10 signs)'
      end
      if !valid_description? params[:description]
        valid_params = false
        flash[:error] = "#{flash[:error]}" + ' || Description is too short (should have more than 50 signs and longer than summary)'
      end

      if valid_params
        packager = params[:packager]
        binaries = params[:selected_binaries]
        relogin = params[:relogin]
        reboot = params[:reboot]
        zypp_restart_needed = params[:zypp_restart_needed]
        if params[:issueid]
          issues = Array.new
          params[:issueid].each_with_index do |new_issue, index|
            issue = Array.new
            issue << new_issue
            issue << params[:issuetracker][index]
            issue << params[:issuesum][index]
            issues << issue
          end
        end
        rating = params[:rating]
        node = Builder::XmlMarkup.new(:indent=>2)
        attrs = {}
        attrs[:incident] = @package.project.name.gsub(/.*:/,'')
        xml = node.patchinfo(attrs) do |n|
          if binaries
            binaries.each do |binary|
              if !binary.blank?
                node.binary(binary)
              end
            end
          end
          node.packager    packager
          if issues
            issues.each do |issue|
              node.issue(issue[2], :tracker=>issue[1], :id=>issue[0])
            end
          end
          node.category    params[:category]
          node.rating      rating
          node.summary     params[:summary]
          node.description params[:description].gsub("\r\n", "\n")
          if reboot
            node.reboot_needed
          end
          if relogin
            node.relogin_needed
          end
          if zypp_restart_needed
            node.zypp_restart_needed
          end
          if params[:block] == 'true'
            node.stopped  params[:block_reason]
          end
        end
        begin
          frontend.put_file( xml, :project => @project,
            :package => @package, :filename => filename)
          flash[:notice] = "Successfully edited #{@package}"
        rescue Timeout::Error 
          flash[:error] = 'Timeout when saving file. Please try again.'
        end

        redirect_to :controller => 'patchinfo', :action => 'show',
          :project => @project.name, :package => @package
      end
      if valid_params == false
        @tracker = params[:tracker]
        @packager = params[:packager]
        @binaries = params[:selected_binaries]
        @binarylist = params[:available_binaries]
        @issues = Array.new
        if params[:issueid]
          params[:issueid].each_with_index do |new_issue, index|
            issue = Array.new
            issue << new_issue
            issue << params[:issuetracker][index]
            issue << params[:issueurl][index]
            issue << params[:issuesum][index]
            @issues << issue
          end
        end
        @category = params[:category]
        @rating = params[:rating]
        @summary = params[:summary]
        @description = params[:description]
        @relogin = params[:relogin]
        @reboot = params[:reboot]
        @zypp_restart_needed = params[:zypp_restart_needed]
        @block = params[:block]
        @block_reason = params[:block_reason]
        render :action => 'edit_patchinfo', :project => @project, :package => @package
      end
    rescue ActiveXML::Transport::UnauthorizedError
      flash[:error] = 'Unauthorized Access'
      redirect_to :action => 'show', :project => @project.name, :package => @package.name
    rescue ActiveXML::Transport::ForbiddenError
      flash[:error] = 'No permission to edit the patchinfo-file.'
      redirect_to :action => 'show', :project => @project.name, :package => @package.name
    end
  end

  def remove
    begin
      FrontendCompat.new.delete_package :project => @project, :package => @package
      flash[:notice] = "'#{@package}' was removed successfully from project '#{@project}'"
      Rails.cache.delete('%s_packages_mainpage' % @project)
      Rails.cache.delete('%s_problem_packages' % @project)
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
    end
    redirect_to :controller => 'project', :action => 'show', :project => @project
  end

  def delete_dialog
    render_dialog
  end

  def valid_summary? name
    name != nil and name =~ /^.{10,}$/m
  end

  def valid_description? name
    name != nil and
      name.length > params[:summary].length and name =~ /^.{50,}$/m
  end

  def new_tracker
    #new_issues = list of new issues to add
    new_issues = params[:issues]
    #collection with all informations of the new issues
    issue_collection = Array.new
    error = String.new
    invalid_format = String.new
    invalid_tracker = String.new
    new_issues.each do |new_issue|
      #issue = collecting all informations of an new issue
      issue = Array.new
      if new_issue.starts_with? 'CVE-'
        issue[0] = 'cve'
        issue[1] = new_issue
      else
        issue = new_issue.split('#')
      end
      if issue.length > 1
        begin
          
          issueurl = IssueTracker.find_by_name(issue[0])
          if issueurl
            Rails.logger.debug "URL2 #{issueurl.inspect}"
            issueurl = issueurl.show_url.sub(/@@@/, issue[1])
            issue << issueurl
            get_issue_sum(issue[0], issue[1])
            if !@error.nil?
              invalid_format += "#{issue[0]} "
              next
            end
            issue << @issuesum
            issue_collection << issue
          else
            invalid_tracker += "#{issue[0]} is not a valid tracker.\n"
          end
        rescue ActiveXML::Transport::NotFoundError
          invalid_format += "#{issue[0]} "
        end
      else
        invalid_format += "#{issue[0]} "
      end
    end
    error += "#{invalid_tracker}" 
    error += "#{invalid_format}has no valid format. (Correct formats are e.g. bnc#123456, CVE-1234-5678 and the string has to be a comma-separated list)" if !invalid_format.empty?
    render :nothing => true, :json => { :error => error, :issues => issue_collection}
  end

  def get_issue_sum(tracker, issueid)
    if !issueid.starts_with? 'CVE-'
      bug = tracker + '#' + issueid
    else
      bug = issueid
    end
    path = "/issue_trackers/#{CGI.escape(tracker)}"
    tracker_result = ActiveXML::Node.new(frontend.transport.direct_http(URI(path), :method => 'GET'))
    regexp = '^'
    regexp += tracker_result.value(:regex)
    regexp += '$'
    regexp = Regexp.new(regexp)
    if bug.match(regexp)
      begin
        path = "/issue_trackers/#{CGI.escape(tracker)}/issues/#{CGI.escape(issueid)}"
        result = ActiveXML::Node.new(frontend.transport.direct_http(URI(path), :method => 'GET'))
        unless result.value(:summary)
          path = "/issue_trackers/#{CGI.escape(tracker)}/issues/#{CGI.escape(issueid)}?force_update=1"
          result = ActiveXML::Node.new(frontend.transport.direct_http(URI(path), :method => 'GET'))
        end
        @issuesum = result.value(:summary) || ''
        @issuesum.gsub!(/\\|'/) { |c| '' }
      # Add no summary if a connection to bugzilla doesn't work e.g. in the testsuite
      rescue ActiveXML::Transport::Error
        @issuesum = ''
      end
    else
      @error = "#{bug} has no valid format"
    end
  end

  private

  def get_binaries
    @binarylist = Array.new
    @binary_list = Buildresult.find(:project => params[:project], :view => 'binarylist')
    @binary_list.to_hash.elements('result') do |r|
      r.elements('binarylist') do |l|
        l.elements('binary') do |b|
          @binarylist << b['filename'].sub(/-[^-]*-[^-]*.rpm$/, '' )
        end
      end
    end
    @binarylist.uniq!
    @binarylist.delete('rpmlint.log')
    @binarylist.delete('updateinfo.xml')
  end

  def require_all
    required_parameters :project
    Rails.logger.debug "require_all #{params[:project]}"
    @project = WebuiProject.find( params[:project] )
    unless @project
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => 'project', :action => 'list_public'
      return false
    end
  end

  def require_exists
    unless params[:package].blank?
      @package = Package.get_by_project_and_name( @project.to_param, params[:package] )
    end
    @patchinfo = @file = @package.patchinfo

    unless @file
      flash[:error] = "Patchinfo not found for #{params[:project]}"
      redirect_to :controller => 'package', :action => 'show', :project => @project, :package => @package and return
    end
  end
end
