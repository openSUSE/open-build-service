require "rexml/document"

class SourceController < ApplicationController
  #TODO: nearly all validations fail, uncomment lines to activate validation
  #validate_action :index => :directory, :packagelist => :directory, :filelist => :directory
  #validate_action :project_meta => :project, :package_meta => :package
  

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
    if request.get?
      forward_data "/source/#{project}/#{package}"
    elsif request.post?
      specfile_path = "/source/#{project}/#{package}/#{package}.spec"
      begin
        Suse::Backend.get( specfile_path )
        render_error "status" => 403, "summary" => "SPEC file already exists."
        return
      rescue Suse::Backend::NotFoundError
        specfile = File.read "#{RAILS_ROOT}/files/specfiletemplate"
        Suse::Backend.put_source( specfile_path, specfile )
      end
      render_ok
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
        response = Suse::Backend.get( path )
	
	# Being here means that the project already exists
	allowed = permissions.project_change? project
      rescue Suse::Backend::NotFoundError
        # Ok, the project  is new
	allowed = permissions.global_project_create
	
	if allowed 
	  # This is a new project. Add the logged in user as maintainer
            request_data = check_and_add_maintainer request_data, "project"
	    logger.debug "Added maintainer to new project, xml is now #{request_data}"
	else
	  # User is not allowed by global permission. 
	  logger.debug "Not allowed to create new packages"
	end
      end
      
      logger.debug response
           
      if allowed
        response = Suse::Backend.put_source path, request_data
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
    project = params[:project]
    package = params[:package]
    path = "/source/#{project}/#{package}/_meta"

    if request.get?
      response = Suse::Backend.get( path )

      result = REXML::Document.new( response.body ).root
      package_element = result.elements["/package"]
      @name = package_element.attributes["name"]
      @description = package_element.elements["description"].text
      @title = package_element.elements["title"].text

      @persons = Array.new
      result.each_element('person') do |p|
        person = Hash.new
        person[ "userid" ] = p.attributes["userid"]
        person[ "role" ] = p.attributes["role"]
        @persons.push person
      end

      @files = Array.new
      result.each_element('file') do |p|
        file = Hash.new
        file[ "filetype" ] = p.attributes["filetype"]
        file[ "filename" ] = p.attributes["filename"]
        @files.push file
      end
    elsif request.put?
      allowed = false
      request_data = request.raw_post
      begin
        # Try to fetch the package to see if it already exists
        response = Suse::Backend.get( path )
	
        # Being here means that the project already exists
        allowed = permissions.package_change? project, package
      rescue Suse::Backend::NotFoundError
        # Ok, the project  is new
	allowed = permissions.package_create?( project )
	
	if allowed 
	  request_data = check_and_add_maintainer request_data, "package"
	else
	  # User is not allowed by global permission. 
	  logger.debug "Not allowed to create new packages"
	end
      end
      
      if allowed
        Suse::Backend.put_source path, request_data
        render_ok
      else
        logger.debug "No permission to PUT on #{path}"
	render_error( :message => "Permission Denied on package", :status => 403 )
      end
    else
      # neither put nor post
      #TODO: return correct error code
      render_error :message => "Illegal request: POST #{path}", :status => 500
    end
  end
  
  def file
    project = params[ :project ]
    package = params[ :package ]
    file = params[ :file ]
    
    path = "/source/#{project}/#{package}/#{file}"

    if request.get?
      forward_data path
    elsif request.put?
      allowed = permissions.package_change? project, package
      if  allowed
        Suse::Backend.put_source path, request.raw_post
        render_ok
      else
        render_error :message => "Permission denied on package write file", :status => 403 
      end
    end
  end
  
  private
  
  def check_and_add_maintainer( data, topelem )
    doc = REXML::Document.new( data )
    # logger.debug "The XML Document: " + doc.to_s
    root = doc.root
    elem = doc.elements["#{topelem}/person[@role='maintainer']"]
	  
    unless elem
      person_elem = doc.elements[topelem].add_element "person"

      person_elem.attributes["userid"] = @http_user.login
      person_elem.attributes["role"] = "maintainer" 
    end
    return doc.to_s
  end
end
