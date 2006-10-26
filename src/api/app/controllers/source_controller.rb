require "rexml/document"

class SourceController < ApplicationController
  validate_action :index => :directory, :packagelist => :directory, :filelist => :directory
  validate_action :project_meta => :project, :package_meta => :package
  

  def index
    projectlist
  end

  def projectlist
    #forward_data "/source"
    @dir = Project.find :all
    render :text => @dir.dump_xml, :content_type => "text/xml"
  end

  def index_project
    project_name = params[:project]
    #forward_data "/source/#{project_name}"
    if request.get?
      @dir = Package.find :all, :project => project_name
      render :text => @dir.dump_xml, :content_type => "text/xml"
      return
    elsif request.delete?

      #allowed = permissions.project_change? project_name
      allowed = user.has_role "Admin"
      if not allowed
        logger.debug "No permission to delete project #{project_name}"
        render_error :message => "Permission denied (delete project #{project_name})", :status => 403, :errorcode => "permission_denied"
        return
      end

      ###
      # FIXME implement in ActiveXML
      ###

      pro = DbProject.find_by_name project_name
      if pro.nil?
        render_error :message => "Unknown project #{project_name}", :status => 404, :errorcode => "unknown_project"
      end

      #check for linking repos
      lreps = Array.new
      pro.repositories.each do |repo|
        repo.linking_repositories.each do |lrep|
          lreps << lrep
        end
      end

      if lreps.length > 0
        lrepstr = lreps.map{|l| l.db_project.name+'/'+l.name}.join "\n"

        render_error :message => "Unable to delete project #{project_name}; following repositories depend on this project:\n#{lrepstr}\n", 
          :status => 404, :errorcode => "repo_dependency"
        return
      end

      #destroy all packages
      pro.db_packages.each do |pack|
        DbPackage.transaction(pack) do
          logger.info "destroying package #{pack.name}"
          pack.destroy
          logger.debug "delete request to backend: /source/#{pro.name}/#{pack.name}"
          Suse::Backend.delete "/source/#{pro.name}/#{pack.name}"
        end
      end

      DbProject.transaction(pro) do
        logger.info "destroying project #{pro.name}"
        pro.destroy
        logger.debug "delete request to backend: /source/#{pro.name}"
        #Suse::Backend.delete "/source/#{pro.name}"
        #FIXME: insert deletion request to backend
      end

      render_ok
      return
    else
      render_error :status => 400, :code => "illegal_request", :message => "illegal POST request to #{request.request_uri}"
    end
  end

  def index_package
    project_name = params[:project]
    package_name = params[:package]
    rev = params[:rev]
    user = params[:user]
    comment = params[:comment]

    path = "/source/#{project_name}/#{package_name}"
    query = Array.new
    query_string = ""

    #get doesn't need to check for permission, so it's handled extra
    if request.get?
      query_string = URI.escape("rev=#{rev}") if rev
      path += "?#{query_string}" unless query_string.empty?

      forward_data path
      return
    end

    user_has_permission = permissions.package_change?( package_name, project_name )

    if request.delete?
      if not user_has_permission
        render_error :status => 403, :errorcode => "permission_denied", :message => "no permission to delete package"
        return
      end
      
      pack = DbPackage.find_by_project_and_name( project_name, package_name )
      if pack
        DbPackage.transaction(pack) do
          pack.destroy
          Suse::Backend.delete "/source/#{project_name}/#{package_name}"
        end
        render_ok
      else
        render_error :status => 404, :errorcode => "unknown_package", :message => "unknown package '#{package_name}' in project '#{project_name}'"
      end
    elsif request.post?
      cmd = params[:cmd]
      
      if not user_has_permission
        render_error :status => 403, :errorcode => "permission_denied", :message => "no permission to execute command '#{cmd}'"
        return
      end

      logger.debug "CMD: #{cmd}"
      if cmd == "createSpecFileTemplate"
        specfile_path = "#{path}/#{package_name}.spec"
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
        repo_name = params[:repo]
        arch_name = params[:arch]

        p = Project.find( project_name )

        if repo_name
          if not ( repo = p.repository( "@name='#{repo_name}'" ) )
            render_error :status => 403, :errorcode => 'unknown_repository', :message=> "Unknown repository '#{repo_name}'"
            return
          end

          if arch_name
            #both
            Suse::Backend.delete_status project_name, repo_name, package_name, arch_name
          else
            #only repo
            repo.each_arch do |arch|
              Suse::Backend.delete_status project_name, repo.name, package_name, arch.to_s
            end
          end
        else
          if arch_name
            #only arch
            p.each_repository do |repo|
              Suse::Backend.delete_status project_name, repo.name, package_name, arch_name
            end
          else
            #neither
            p.each_repository do |repo|
              repo.each_arch do |arch|
                Suse::Backend.delete_status project_name, repo.name, package_name, arch.to_s
              end
            end
          end
        end

        render_ok
      elsif cmd == "commit"
        query << URI.escape("rev=#{rev}") if rev
        query << URI.escape("user=#{user}") if user
        query << URI.escape("comment=#{comment}") if comment
        query_string = query.join('&')
        path += "?#{query_string}" unless query_string.empty?

        forward_data path, :method => :post
      else
        render_error :status => 400, :message => "unknown command: #{cmd}"
      end
    end
  end

  def project_meta
    project_name = params[:project]

    if request.get?
      @project = Project.find( project_name )
      render :text => @project.dump_xml, :content_type => 'text/xml'
      return
    elsif request.put?
      # Need permission
      logger.debug "Checking permission for the put"
      allowed = false
      request_data = request.raw_post

      begin
        # Try to fetch the project to see if it already exists
        @project = Project.find( project_name )
	
	# Being here means that the project already exists
	allowed = permissions.project_change? project_name
        if allowed
          @project = Project.new( request_data, :name => project_name )
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
          @project = Project.new( request_data, :name => project_name )

          if( @project.name != project_name )
            render_error( :message => "project name in xml data does not match resource path component", :status => 404 )
            return
          end
         
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
        render_ok
      else
        logger.debug "No permissions to write project meta for project #@project"
	render_error( :message => "Permission denied (write project meta for project #@project)", :status => 403 )
        return
      end
    else
      #neither put nor get
      #TODO: return correct error code
      render_error :message => "Illegal request: POST #{request.path}", :status => 500
    end
  end

  def package_meta
    #TODO: needs cleanup/split to smaller methods
   
    project_name = params[:project]
    package_name = params[:package]

    if request.get?
      @package = Package.find( package_name, :project => project_name )
      render :text => @package.dump_xml, :content_type => 'text/xml'
    elsif request.put?
      allowed = false
      request_data = request.raw_post
      begin
        # Try to fetch the package to see if it already exists
        @package = Package.find( package_name, :project => project_name )
	
        # Being here means that the project already exists
        allowed = permissions.package_change? @package
        if allowed
          @package = Package.new( request_data, :project => project_name, :name => package_name )
        else
          logger.debug "user #{user.login} has no permission to change package #{@package}"
	  render_error( :message => "no permission to change package", :status => 403 )
          return
        end
      rescue ActiveXML::Transport::NotFoundError
        # Ok, the project is new
	allowed = permissions.package_create?( project_name )
	
        if allowed
          #FIXME: parameters that get substituted into the url must be specified here... should happen
          #somehow automagically... no idea how this might work
          @package = Package.new( request_data, :project => project_name, :name => package_name )
          if( @package.name != package_name )
            render_error( :message => "package name in xml data does not match resource path component", :status => 404 )
            return
          end

          # add package creator as maintainer if he is not added already
          if not @package.has_element?( "person[@userid='#{user.login}']" )
            @package.add_person( :userid => user.login )
          end
        else
          # User is not allowed by global permission.
          logger.debug "Not allowed to create new packages"
          render_error( :message => "no permission to create package for project #{project_name}", :status => 403 )
          return
        end
      end
      
      if allowed
        @package.save
        render_ok
      else
        logger.debug "user #{user.login} has no permission to write package meta for package #@package"
      end
    else
      # neither put nor get
      #TODO: return correct error code
      render_error :message => "Illegal request: POST #{request.path}", :status => 500
    end
  end

  def file
    project_name = params[ :project ]
    package_name = params[ :package ]
    file = params[ :file ]
    rev = params[:rev]
    user = params[:user]
    comment = params[:comment]

    
    path = "/source/#{project_name}/#{package_name}/#{file}"
    query = Array.new
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
      
      allowed = permissions.package_change? package_name, project_name
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
