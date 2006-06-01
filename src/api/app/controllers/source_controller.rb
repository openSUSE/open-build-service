require "rexml/document"

class SourceController < ApplicationController
  #TODO: nearly all validations fail, uncomment lines to activate validation
  validate_action :index => :directory, :packagelist => :directory, :filelist => :directory
  validate_action :project_meta => :project, :package_meta => :package
  

  def index
    projectlist
  end

  def projectlist
    forward_data "/source"
  end

  def index_project
    project = params[:project]
    forward_data "/source/#{project}"
  end

  def index_package
    project = params[:project]
    package = params[:package]
    rev = params[:rev]
    user = params[:user]
    comment = params[:comment]

    path = "/source/#{project}/#{package}"

    if request.get?
      query_string = URI.escape("rev=#{rev}") if rev
      path += "?#{query_string}" unless query_string.empty?

      forward_data path
    elsif request.post?
      cmd = params[:cmd]
      logger.debug "CMD: #{cmd}"
      if cmd == "createSpecFileTemplate"
        specfile_path = "#{path}/#{package}.spec"
        begin
          backend_get( specfile_path )
          render_error :status => 403, :message => "SPEC file already exists."
          return
        rescue ActiveXML::Transport::NotFoundError
          specfile = File.read "#{RAILS_ROOT}/files/specfiletemplate"
          backend_put( specfile_path, specfile )
        end
        render_ok
      elsif cmd == "rebuild"
        p = Project.find( project )

        p.each_repository do |repo|
          repo.each_arch do |arch|
            Suse::Backend.delete_status project, repo.name, package, arch.to_s
          end
        end
        render_ok
      elsif cmd == "commit"
        query << URI.escape("rev=#{rev}") if rev
        query << URI.escape("user=#{user}") if user
        query << URI.escape("comment=#{comment}") if comment
        query_string = query.join('&')
        path += "?#{query_string}" unless query_string.empty?

        forward_data path
      else
        render_error :status => 404, :message => "Unknow command: #{cmd}"
      end
    end
  end

  def project_meta
    project = params[:project]
    path = "/source/#{project}/_meta"
    
    request_data = request.raw_post

    if request.get?
      forward_data path
    elsif request.put?
      # Need permission
      logger.debug "Checking permission for the put"
      allowed = false
      begin
        # Try to fetch the project to see if it already exists
        @project = Project.find( project )
        #response = Suse::Backend.get( path )
	
	# Being here means that the project already exists
	allowed = permissions.project_change? project
        if allowed
          @project.raw_data = request_data
        else
          logger.debug "user #{user.login} has no permission to change project #{@project}"
	  render_error( :message => "no permission to change project", :status => 403 )
          return
        end
      rescue ActiveXML::Transport::NotFoundError
        # Ok, the project  is new
	allowed = permissions.global_project_create
	
	if allowed 
	  # This is a new project. Add the logged in user as maintainer
          @project = Project.new( request_data, :name => project )
         
          if not @project.has_element?( "person[@userid='#{user.login}']" )
            @project.add_person( :userid => user.login )
          end
	else
	  # User is not allowed by global permission. 
	  logger.debug "Not allowed to create new projects"
          render_error( :message => "not allowed to create new projects", :status => 403 )
          return
	end
      end
      
      logger.debug response
           
      if allowed
        @project.save
        #response = Suse::Backend.put_source path, request_data
        render_ok
      else
        logger.debug "No permissions to PUT on #{path}"
	render_error( :message => "Permission Denied", :status => 403 )
      end
    else
      #neither put nor post
      #TODO: return correct error code
      render_error :message => "Illegal request: POST #{path}", :status => 500
    end
  end

  def package_meta
    #TODO: needs cleanup/split to smaller methods
    project = params[:project]
    package = params[:package]
    path = "/source/#{project}/#{package}/_meta"

    if request.get?
      @package = Package.find( package, :project => project )
    elsif request.put?
      allowed = false
      request_data = request.raw_post
      begin
        # Try to fetch the package to see if it already exists
        @package = Package.find( package, :project => project )
	
        # Being here means that the project already exists
        allowed = permissions.package_change? @package
        if allowed
          @package.raw_data = request_data
        else
          logger.debug "user #{user.login} has no permission to change package #{@package}"
	  render_error( :message => "no permission to change package", :status => 403 )
          return
        end
      rescue ActiveXML::Transport::NotFoundError
        # Ok, the project  is new
	allowed = permissions.package_create?( project )
	
        if allowed
          #FIXME: parameters that get substituted into the url must be specified here... should happen
          #somehow automagically... no idea how this might work
          @package = Package.new( request_data, :project => project, :name => package )

          # add package creator as maintainer if he is not added already
          if not @package.has_element?( "person[@userid='#{user.login}]'" )
            @package.add_person( :userid => user.login )
          end
        else
          # User is not allowed by global permission.
          logger.debug "Not allowed to create new packages"
          render_error( :message => "no permission to create package for project #{project}", :status => 403 )
          return
        end
      end
      
      if allowed
        @package.save
        render_ok
      else
        logger.debug "user #{user.login} no permission to PUT on #{path}"
      end
    else
      # neither put nor get
      #TODO: return correct error code
      render_error :message => "Illegal request: POST #{path}", :status => 500
    end
  end

  def file
    project = params[ :project ]
    package = params[ :package ]
    file = params[ :file ]
    rev = params[:rev]
    user = params[:user]
    comment = params[:comment]

    
    path = "/source/#{project}/#{package}/#{file}"
    query = Array.new
    query = nil
    query_string = ""

    if request.get?
      query_string = URI.escape("rev=#{rev}") if rev
      path += "?#{query_string}" unless query_string.empty?

      forward_data path
    elsif request.put?
      query << URI.escape("rev=#{rev}") if rev
      query << URI.escape("user=#{user}") if user
      query << URI.escape("comment=#{comment}") if comment
      query_string = query.join('&')
      path += "?#{query_string}" unless query_string.empty?
      
      allowed = permissions.package_change? package, project
      if  allowed
        Suse::Backend.put_source path, request.raw_post
        render_ok
      else
        render_error :message => "Permission denied on package write file", :status => 403 
      end
    elsif request.delete?
      query << URI.escape("rev=#{rev}") if rev
      query << URI.escape("user=#{user}") if user
      query << URI.escape("comment=#{comment}") if comment
      query_string = query.join('&')
      path += "?#{query_string}" unless query_string.empty?
      
      Suse::Backend.delete path
      render_ok
    end
  end
end
