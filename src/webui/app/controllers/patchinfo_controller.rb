class PatchinfoController < ApplicationController
  include ApplicationHelper
  before_filter :require_all
  before_filter :get_tracker, :get_binaries, :except => [:show, :delete]
  before_filter :require_exists, :except => [:new_patchinfo]
  helper :package

  def new_patchinfo
    unless find_cached(Package, "patchinfo", :project => @project )
      begin
        path = "/source/#{CGI.escape(params[:project])}?cmd=createpatchinfo"
        frontend.transport.direct_http( URI(path), :method => "POST" )
      rescue ActiveXML::Transport::Error => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        flash[:error] = message
        redirect_to :controller => 'project', :action => 'show'
      end
    end
    @package = find_cached(Package, "patchinfo", :project => @project )
    @file = find_cached(Patchinfo, :project => @project, :package => @package )
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
    frontend.transport.direct_http( URI(path), :method => "POST" )
    Patchinfo.free_cache(:project=> @project, :package => @package)
    redirect_to :action => "edit_patchinfo", :project => @project, :package => @package
  end

  def edit_patchinfo
    read_patchinfo
    @tracker = "bnc"
    @binaries.each do |bin|
      if @binarylist.find(bin)
        @binarylist.delete(bin)
      end
    end
  end

  def show
    read_patchinfo
    @pkg_names = Array.new
    packages = find_cached(Package, :all, :project => @project.name, :expires_in => 30.seconds )
    packages.each do |pkg|
      @pkg_names << pkg.value(:name)
    end
    @pkg_names.delete("patchinfo")
    @description = @description.gsub(/\n/, "<br/>").html_safe
    @summary = @summary.gsub(/\n/, "<br/>").html_safe
    @packager = Person.find(:login => @packager)
  end

  def read_patchinfo
    @binaries = Array.new
    if @file.has_element?("binary")
      @file.each_binary do |binaries|
        @binaries << binaries.text
      end
    end
    @binary = []
    @packager = @file.packager.to_s
    @issues = []
    if @file.has_element?("issue")
      @file.each_issue do |a|
        if a.text == ""
          get_issue_sum(a.tracker, a.value(:id))
        end
        issue = Array.new
        issueid = a.value(:id)
        issueurl = IssueTracker.find(:name => a.tracker)
        issueurl = issueurl.each("/issue-tracker/show-url").first.text
        issueurl = issueurl.sub(/@@@/, issueid)
        issue << a.tracker
        issue << issueid
        issue << issueurl
        issue << a.text
        @issues << issue
      end
    end
   
    if params[:issue] == nil
      params[:issue] = Array.new
      params[:issue] << params[:issueid]
    end
    if params[:issueid] != nil
      params[:issue] << params[:issueid]
      @issues = params[:issue]
    end
    @category = @file.category.to_s
    @rating = @file.rating.to_s if @file.rating

    @description = @summary = @category = nil
    @category = @file.category.to_s       if @file.has_element? 'category'
    @rating = @file.rating.to_s           if @file.has_element? 'rating'
    @summary = @file.summary.text if @file.has_element? 'summary'
    
    @description = @file.description.text if @file.has_element? 'description'
    if @file.has_element?("relogin_needed")
      @relogin = true
    else
      @relogin = false
    end
    if @file.has_element?("reboot_needed")
      @reboot = true
    else
      @reboot = false
    end
    if @file.has_element?("zypp_restart_needed")
      @zypp_restart_needed = true
    else
      @zypp_restart_needed = false
    end
    if @file.has_element?("stopped")
      @block = true
      @block_reason = @file.stopped.text
    end
  end

  def save
    valid_http_methods :post
    filename = "_patchinfo"
    valid_params = true
    required_parameters :project, :package
    flash[:error] = nil
    if !valid_summary? params[:summary]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Summary is too short (should have more than 10 signs)"
    end
    if !valid_description? params[:description]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Description is too short (should have more than 50 signs and longer than summary)"
    end

    if valid_params == true
      #name = "binary"
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
      attrs[:incident] = @package.project.gsub(/.*:/,'')
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
        if params[:block] == "true"
          node.stopped  params[:block_reason]
        end
      end
      begin
        frontend.put_file( xml, :project => @project,
          :package => @package, :filename => filename)
        flash[:note] = "Successfully edited #{@package}"
      rescue Timeout::Error 
        flash[:error] = "Timeout when saving file. Please try again."
      end

      Package.free_cache( :all, :project => @project.name )
      Package.free_cache( @package.name, :project => @project )
      redirect_to :controller => "patchinfo", :action => "show",
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
      render :action => "edit_patchinfo", :project => @project, :package => @package
    end
  end

  def remove
    valid_http_methods(:post)
    begin
      FrontendCompat.new.delete_package :project => @project, :package => @package
      flash[:note] = "'#{@package}' was removed successfully from project '#{@project}'"
      Rails.cache.delete("%s_packages_mainpage" % @project)
      Rails.cache.delete("%s_problem_packages" % @project)
      Package.free_cache( :all, :project => @project.name )
      Package.free_cache( @package, :project => @project )
      Patchinfo.free_cache(:project=> @project, :package => @package)
    rescue ActiveXML::Transport::Error => e
      message = ActiveXML::Transport.extract_error_message(e)[0]
      flash[:error] = message
    end
    redirect_to :controller => 'project', :action => 'show', :project => @project
  end

  def delete_dialog
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
    error = ""
    new_issues.each do |new_issue|
      #issue = collecting all informations of an new issue
      issue = Array.new
      if new_issue.starts_with? "CVE-"
        issue[0] = "cve"
        issue[1] = new_issue
      elsif
        issue = new_issue.split("#")
      end
      begin
        issueurl = IssueTracker.find(:name => issue[0])
        issueurl = issueurl.each("/issue-tracker/show-url").first.text
        issueurl = issueurl.sub(/@@@/, issue[1])
        issue << issueurl
        get_issue_sum(issue[0], issue[1])
        issue << @issuesum
        issue_collection << issue
      rescue
        error += "#{issue[0]} "
      end
    end
    error += "has no valid format" if error != ""
    render :nothing => true, :json => { :error => error, :issues => issue_collection}
  end

  def get_issue_sum(tracker, issueid)
    if !issueid.starts_with? "CVE-"
      bug = tracker + "#" + issueid
    else
      bug = issueid
    end
    path = "/issue_trackers/#{CGI.escape(tracker)}"
    tracker_result = ActiveXML::Node.new(frontend.transport.direct_http(URI(path), :method => "GET"))
    regexp = "^"
    regexp += tracker_result.regex.text
    regexp += "$"
    regexp = Regexp.new(regexp)
    if bug =~ regexp
      path = "/issue_trackers/#{CGI.escape(tracker)}/issues/#{CGI.escape(issueid)}"
      result = ActiveXML::Node.new(frontend.transport.direct_http(URI(path), :method => "GET"))
      if result.summary.nil?
        path = "/issue_trackers/#{CGI.escape(tracker)}/issues/#{CGI.escape(issueid)}?force_update=1"
        result = ActiveXML::Node.new(frontend.transport.direct_http(URI(path), :method => "GET"))
      end
      @issuesum = result.summary.text if result.summary
      @issuesum = "" if !result.summary
      @issuesum.gsub!(/\\|'/) { |c| "" }
    else
      @error = "#{bug} has no valid format"
    end
  end

  private

  def get_tracker
    issue_tracker = IssueTracker.find(:all)
    @trackerlist = []
    issue_tracker.each do |a| @trackerlist << a.name.to_s end
    @trackerlist.sort!
    @trackerlist.unshift(@trackerlist.delete_at(@trackerlist.index("cve")))
    @trackerlist.unshift(@trackerlist.delete_at(@trackerlist.index("bnc")))
  end

  def get_binaries
    @binarylist = Array.new
    @binary_list = Buildresult.find(:project => params[:project], :view => 'binarylist')
    @binary_list.to_hash.elements("result") do |r|
      r.elements("binarylist") do |l|
        l.elements("binary") do |b|
          @binarylist << b["filename"].sub(/-[^-]*-[^-]*.rpm$/, '' )
        end
      end
    end
    @binarylist.uniq!
    @binarylist.delete("rpmlint.log")
    @binarylist.delete("updateinfo.xml")
  end

  def require_all
    @project = find_cached(Project, params[:project] )
    unless @project
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
      return
    end
  end

  def require_exists
    unless params[:package].blank?
      @package = find_cached(Package, params[:package], :project => @project )
    end
    @file = find_cached(Patchinfo, :project => @project, :package => @package )
    opt = {:project => @project.name, :package => @package}
    opt.store(:patchinfo, @patchinfo.to_s)
    @patchinfo = Patchinfo.find(opt)

    unless @file
      flash[:error] = "Patchinfo not found for #{params[:project]}"
      redirect_to :controller => 'package', :action => 'show', :project => @project, :package => @package and return
    end
  end
end
