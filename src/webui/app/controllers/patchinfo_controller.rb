class PatchinfoController < ApplicationController
  include ApplicationHelper
  before_filter :require_all
  before_filter :require_exists, :except => [:save_new, :new_patchinfo]
  helper :package

  def new_patchinfo
    @packager = @project.person.userid
    @buglist = Array.new
    @cvelist = Array.new
    @binaries = Array.new
  end

  def save_new
    valid_http_methods(:post)
    
    valid_params = true
    if binaries_selected? params[:binaries]
      valid_params = false
      flash[:error] = "|| No binaries selected"
    end
    if !valid_bugzilla_number? params[:bug]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + "|| Invalid bugzilla number: '#{params[:bugid]}'"
    end
    if !valid_swampid? params[:swampid]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Invalid swampid: '#{params[:swampid]}'"
    end
    if !valid_summary? params[:summary]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Summary is too short (should have more than 10 signs)"
    end
    if !valid_description? params[:description]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Description is too short (should have more than 100 signs and longer than summary)"
    end
    if params[:category] == "security"
      debugger
      if !valid_cve_number? params[:cve]
        valid_params = false
        flash[:error] = "#{flash[:error]}" + " || CVE-Number has the wrong format. Expected \"cve-year-number\""
      end
    end

    if valid_params == true
      filename = "_patchinfo"
      name = params[:name]
      packager = @project.person.userid
      if params[:cve] != nil
        cvelist = params[:cve]
      else
        cvelist = Array.new
      end
      binaries = params[:binaries]
      if params[:bug] != nil
        buglist = params[:bug]
      else
        buglist = Array.new
      end
      category = params[:category]
      swampid = params[:swampid]
      summary = params[:summary]
      description = params[:description]
      relogin = params[:relogin]
      reboot = params[:reboot]
      name=""
      if params[:name]
        name=params[:name] if params[:name]
      end
      pkg_name = "_patchinfo:#{name.gsub(/\W/, '_')}"
      if package_exists? @project, pkg_name
        @name = params[:name]
        @packager = @project.person.userid
        if params[:cve] != nil
          @cvelist = params[:cve]
        else
          @cvelist = Array.new
        end
        @binaries = params[:binaries]
        if params[:bug] != nil
          @buglist = params[:bug]
        else
          @buglist = Array.new
        end
        @category = params[:category]
        @swampid = params[:swampid]
        @summary = params[:summary]
        @description = params[:description]
        @relogin = params[:relogin]
        @reboot = params[:reboot]
        flash[:error] = "Patchinfo '#{pkg_name}' already exists in project '#{@project}'"
        render :controller => :patchinfo, :action => 'new_patchinfo', :project => @project
        return
      end
      pkg = Package.new(:name => pkg_name, :project => @project,
        :title => "Patchinfo", :description => "Collected packages for update")
      pkg.save
      if name==""
        name=pkg_name
      end

      node = Builder::XmlMarkup.new(:indent=>2)
      xml = node.patchinfo(:name => name) do |n|
        binaries.each do |binary|
          node.binary(binary)
        end
        node.packager    packager
        buglist.each do |bug|
          node.bugzilla(bug)
        end
        node.swampid     swampid
        node.category    category
        if category == "security"
          cvelist.each do |cve|
            node.CVE(cve)
          end
        end
        node.summary     summary
        node.description description
        node.reboot_needed reboot
        node.relogin_needed relogin
      end
      begin
        frontend.put_file( xml, :project => @project,
          :package => pkg, :filename => filename,
          :category => [:category], :bug => [:bug],
          :cve => [:cve],
          :binarylist => [:binarylist],
          :binaries => [:binaries], :swampid => [:swampid],
          :summary => [:summary], :description => [:description],
          :relogin => [:relogin], :reboot => [:reboot])
        flash[:note] = "Successfully saved #{pkg_name}"
      rescue Timeout::Error => e
        flash[:error] = "Timeout when saving file. Please try again."
      end
      redirect_to :controller => "patchinfo", :action => "show",
        :project => @project.name, :package => pkg_name
    end
    
    if valid_params == false
      @name = params[:name]
      @packager = @project.person.userid
      if params[:cve] != nil
        @cvelist = params[:cve]
      else
        @cvelist = Array.new
      end

      @binaries = params[:binaries]
      if params[:bug] != nil
        @buglist = params[:bug]
      else
        @buglist = Array.new
      end
      @category = params[:category]
      @swampid = params[:swampid]
      @summary = params[:summary]
      @description = params[:description]
      @relogin = params[:relogin]
      @reboot = params[:reboot]
      render :controller => :patchinfo, :action => "new_patchinfo", :project => @project
    end
  end

  def edit_patchinfo
    read_patchinfo
  end

  def show
    read_patchinfo
    @description.gsub!("\r\n", "<br/>")
    @summary.gsub!("\r\n", "<br/>")
    if @relogin == true
      @relogin = "yes"
    elsif @relogin == false
      @relogin = "no"
    end
    if @reboot == true
      @reboot ="yes"
    elsif @reboot == false
      @reboot = "no"
    end
  end

  def read_patchinfo
    @binaries = Array.new
    @file.each_binary do |binaries|
      @binaries << binaries.text
    end
    @binary = []
    @packager = @file.packager.to_s
    @bugzilla = []
    @file.each_bugzilla do |bugzilla|
      @bugzilla << bugzilla.text
    end if @file
    if @buglist == nil
      @buglist = @bugzilla
    end  
    if params[:bug] == nil
      params[:bug] = Array.new
      params[:bug] << params[:bugid]
    end
    if params[:bugid] != nil
      params[:bug] << params[:bugid]
      @buglist = params[:bug]
    end
    @category = @file.category.to_s
    @cves = []
    @cvelist = []
    if @category == "security"
      if @file.has_element?("CVE")
        @file.each_CVE do |cve|
          @cves << cve.text
        end if @file
        if @cvelist.empty?
          @cvelist = @cves
        end
        if params[:cve] == nil
          params[:cve] = Array.new
          params[:cve] << params[:cveid]
        end
        if params[:cveid] != nil
          params[:cve] << params[:cveid]
          @cvelist = params[:cve]
        end
      end
    end

    @swampid = @file.swampid.to_s
    @category = @file.category.to_s
    @summary = @file.summary.to_s
    @description = @file.description.to_s
    if @file.has_element?("relogin_needed")
      @relogin = @file.relogin_needed.to_s
      if @relogin == ""
        @relogin = false
      elsif @relogin == "true"
        @relogin = true
      end
    else
      @relogin = false
    end
    if @file.has_element?("reboot_needed")
      @reboot = @file.reboot_needed.to_s
      if @reboot == ""
        @reboot = false
      elsif @reboot == "true"
        @reboot = true
      end
    else
      @reboot = false
    end
  end

  def save
    filename = "_patchinfo"
    valid_params = true
    if request.method != :post
      flash[:warn] = "Saving Patchinfo failed because this was no POST request. " +
        "This probably happened because you were logged out in between. Please try again."
      redirect_to :controller => "patchinfo", :action => "create", :project => @project, :package => @package
    end
    required_parameters :project, :package
    file = @file.data
    if !valid_bugzilla_number? params[:bug]
      valid_params = false
      flash[:error] = "|| Invalid bugzilla number: '#{params[:bugid]}'"
    end
    if !valid_swampid? params[:swampid]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Invalid swampid: '#{params[:swampid]}'"
    end
    if !valid_summary? params[:summary]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Summary is too short (should have more than 10 signs)"
    end
    if !valid_description? params[:description]
      valid_params = false
      flash[:error] = "#{flash[:error]}" + " || Description is too short (should have more than 100 signs and longer than summary)"
    end
    if params[:category] == "security"
      if !valid_cve_number? params[:cve]
        valid_params = false
        flash[:error] = "#{flash[:error]}" + " || CVE-Number has the wrong format. Expected \"cve-year-number\""
      end
    end

    if valid_params == true
      name = "binary"
      cvelist = params[:cve]
      binaries = params[:binaries]
      relogin = params[:relogin]
      reboot = params[:reboot]
      buglist = params[:bug]
      if params[:category] != "security"
        cvelist = ""
      end
      @patchinfo.set_cve(cvelist)
      @patchinfo.set_binaries(binaries, name)
      @patchinfo.category.text = params[:category]
      @patchinfo.swampid.text = params[:swampid]
      @patchinfo.summary.text = params[:summary]
      @patchinfo.description.text = params[:description]
      @patchinfo.set_buglist(buglist)
      @patchinfo.set_relogin(relogin.to_s)
      @patchinfo.set_reboot(reboot.to_s)
      @patchinfo = @patchinfo.data.to_s
      @patchinfo.gsub!( /\r\n/, "\n" )
      begin
        frontend.put_file( @patchinfo, :project => @project,
          :package => @package,:filename => filename,
          :category => [:category], :bug => [:bug],
          :cve => [:cve],
          :binarylist => [:binarylist],
          :binaries => [:binaries], :swampid => [:swampid],
          :summary => [:summary], :description => [:description],
          :relogin => [:relogin], :reboot => [:reboot])
        flash[:note] = "Successfully edited #{@package}"
      rescue Timeout::Error => e
        flash[:error] = "Timeout when saving file. Please try again."
      end
      opt = {:controller => "patchinfo", :action => "show", :project => @project.name, :package => @package }
      redirect_to opt
    end
    if valid_params == false
      @packager = @file.packager.to_s
      @cvelist = params[:cve]
      @binaries = params[:binaries]
      @buglist = params[:bug]
      @category = params[:category]
      @swampid = params[:swampid]
      @summary = params[:summary]
      @description = params[:description]
      @relogin = params[:relogin]
      @reboot = params[:reboot]
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
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
    end
    redirect_to :controller => 'project', :action => 'show', :project => @project
  end

  def binaries_selected? name
    name.nil?
  end

  def valid_bugzilla_number? name
    name != nil and name.each do |bug|
      bug =~ /^\d{6,8}$/
    end
  end

  def valid_cve_number? name
    name != nil and name.each do |cve|
      cve =~ /^cve-\d{4}-\d{4}$/
    end
  end

  def valid_swampid? name
    name != nil and name =~ /^\d{5,}$/
  end

  def valid_summary? name
    name != nil and name =~ /^.{10,}$/m
  end

  def valid_description? name
    name != nil and
      name.length > params[:summary].length and name =~ /^.{100,}$/m
  end



  private

  def require_all
    @project = find_cached(Project, params[:project] )
    unless @project
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
      return
    end
    @binarylist = Array.new
    @binary_list = Buildresult.find(:project => params[:project], :view => 'binarylist')
    @binary_list.each_result do |r|
      r.each_binarylist do |l|
        l.each_binary do |b|
          @binarylist << b.filename.sub(/-[^-]*-[^-]*.rpm$/, '' )
        end
      end
    end
    @binarylist.uniq!
    @binarylist.delete("rpmlint.log")
  end

  def require_exists
    unless params[:package].blank?
      @package = find_cached(Package, params[:package], :project => @project )
    end
    @file = find_cached(Patchinfo, :project => @project, :package => @package )
    opt = {:project => @project.name, :package => @package}
    opt.store(:patchinfo, @patchinfo.to_s)
    @patchinfo = Patchinfo.find(opt)
  end
end
