class PatchinfoController < ApplicationController
  before_filter :requires
  helper :package

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
    logger.debug( "PATCHINFO: #{@file.data}" )
    @binaries = Array.new
    @file.each_binary do |binaries|
      @binaries << binaries.text
    end
    @binary = []
    @rating = []
    @packager = @file.packager.to_s
    
    if params[:bug] == nil
      params[:bug] = Array.new
      params[:bug] << params[:bugid]
    end
    if params[:bugid] != nil  
      params[:bug] << params[:bugid]
      @buglist = params[:bug]
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
      flash[:error] = ""
      if !valid_bugzilla_number? params[:bug]
        valid_params = false
        flash[:error] = "Contains invalid bugzilla number.\n"
      end
      if !valid_swampid? params[:swampid]
        valid_params = false
        flash[:error] = "#{flash[:error]}Invalid swampid: '#{params[:swampid]}'\n"
      end
      if !valid_summary? params[:summary]
        valid_params = false
        flash[:error] = "#{flash[:error]}Summary is too short (should have more than 10 characters)\n"
      end
      if !valid_description? params[:description]
        valid_params = false
        flash[:error] = "#{flash[:error]}Description is too short (should have more than 100 characters and longer than summary)"
      end
      if valid_params == true
        name = "binary"
        packager = params[:packager]
        binaries = params[:binaries]
        relogin = params[:relogin]
        reboot = params[:reboot]
        buglist = params[:bug]
        bugzilla = "bugzilla"
        @patchinfo.set_binaries(binaries, name)
        @patchinfo.category.text = params[:category]
        @patchinfo.swampid.text = params[:swampid]
        @patchinfo.summary.text = params[:summary]
        @patchinfo.description.text = params[:description]
        @patchinfo.set_buglist(buglist, bugzilla)
        @patchinfo.set_relogin(relogin.to_s)
        @patchinfo.set_reboot(reboot.to_s)
        @patchinfo = @patchinfo.data.to_s
        @patchinfo.gsub!( /\r\n/, "\n" )
        begin
          frontend.put_file( @patchinfo, :project => @project, :package => @package, :filename => filename)
          flash[:note] = "Successfully saved patchinfo."
        rescue Timeout::Error => e
          flash[:error] = "Timeout when saving file. Please try again."
        end
        redirect_to :controller => "package", :action => "show", :project => @project, :package => @package and return
      end
      if valid_params == false
        @packager = params[:packager]
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
 
  def valid_bugzilla_number? bugids
    bugids.each do |bug|
      return false unless bug =~ /^\d{6,8}$/
    end
  end

  def valid_swampid? name
    name =~ /^\d{5,}$/
  end

  def valid_summary? name
    name =~ /^.{10,}$/
  end

  def valid_description? name
    name.length > params[:summary].length and name =~ /^.{100,}$/
  end
    
 

  private
  
  def requires
    @project = find_cached(Project, params[:project] )
    unless @project
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
      return
    end
    @bugzilla = []
    unless params[:package].blank?
      @package = find_cached(Package, params[:package], :project => @project )
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

    @file = find_cached(Patchinfo, :project => @project, :package => @package )
    @file.each_bugzilla do |bugzilla|
      @bugzilla << bugzilla.text
    end if @file
    
    if @buglist == nil
      @buglist = @bugzilla
    end
    opt = {:project => @project.name, :package => @package}
    opt.store(:patchinfo, @patchinfo.to_s)
    @patchinfo = Patchinfo.find(opt)
  end
end
