class TagController < ApplicationController
  validate_action tags_by_user_and_object: {method: :get, response: :tags}
  validate_action project_tags: {method: :get, response: :tags}
  validate_action package_tags: {method: :get, response: :tags}

  class TagNotFoundError < APIException
    setup 'tag_not_found', 404, "Tag not found"
  end

  # list all available tags as xml list
  def list_xml
    @taglist = Tag.all
    render partial: "listxml"
  end

  def get_tagged_projects_by_user
    @user = User.find_by_login!(params[:user])

    @taggings = Tagging.where("taggable_type = ? AND user_id = ?", "Project", @user.id)
    @projects_tags = {}
    @taggings.each do |tagging|
      project = Project.find(tagging.taggable_id)
      tag = Tag.find(tagging.tag_id)
      @projects_tags[project] = [] if @projects_tags[project].nil?
      @projects_tags[project] <<  tag
    end
    @projects_tags.keys.each do |key|
      @projects_tags[key].sort!{ |a, b| a.name.downcase <=> b.name.downcase }
    end
    @my_type = "project"
    render partial: "tagged_objects_with_tags"
  end

  def get_tagged_packages_by_user
    @user = User.find_by_login!(params[:user])
    @taggings = Tagging.where("taggable_type = ? AND user_id = ?", "Package", @user.id)
    @packages_tags = {}
    @taggings.each do |tagging|
      package = Package.find(tagging.taggable_id)
      tag = Tag.find(tagging.tag_id)
      @packages_tags[package] = [] if @packages_tags[package].nil?
      @packages_tags[package] <<  tag
    end
    @packages_tags.keys.each do |key|
      @packages_tags[key].sort!{ |a, b| a.name.downcase <=> b.name.downcase }
    end
    @my_type = "package"
    render partial: "tagged_objects_with_tags"
  end

  def get_tags_by_user
    @user = @http_user
    @tags = @user.tags.group(:name)
    @tags
  end

  def get_projects_by_tag ( do_render = true )
    @tag = params[:tag]
    @projects = Array.new

     first_run = true

    @tag.split('::').each do |t|
      tag = Tag.find_by_name(t)
      raise TagNotFoundError.new("Tag #{t} not found") unless tag

      if first_run
        @projects = tag.projects.group(:name).order(:name)
        first_run = false
      else
        @projects = @projects & tag.projects.group(:name).order(:name)
      end
    end

    if do_render
      render partial: "objects_by_tag"
      return
    end
    @projects
  end

  def get_packages_by_tag( do_render = true )
    @tag = params[:tag]
    @packages = Array.new

    first_run = true

    @tag.split('::').each do |t|
      tag = Tag.find_by_name(t)
      raise TagNotFoundError.new("Tag #{t} not found") unless tag

      if first_run
        @packages = tag.packages.group(:name).order(:name)
        first_run = false
      else
        @packages = @packages & tag.packages.group(:name).order(:name)
      end
    end

    if do_render
      render partial: "objects_by_tag"
      return
    end
    @packages
  end

  def get_objects_by_tag
    @projects = get_projects_by_tag( false )
    @packages = get_packages_by_tag( false )

    render partial: "objects_by_tag"
  end

  def tags_by_user_and_object
    if request.get?
      if params[:package]
        get_tags_by_user_and_package
      else
        get_tags_by_user_and_project
      end
    elsif request.put?
      update_tags_by_object_and_user
    end
  end

  def get_tags_by_user_and_project( do_render = true )
    user = User.find_by_login!(params[:user])
    @type = "project"
    @name = params[:project]
    @project = Project.get_by_name(params[:project])

    @tags = @project.tags.where("taggings.user_id = ?", user.id).order(:name)
    if do_render
      render partial: "tags"
    else
      return @tags
    end
  end

  def get_tags_by_user_and_package( do_render = true  )
    user = User.find_by_login!(params[:user])
    @type = "package"

    @name = params[:package]
    @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_project_links: false)
    @project = @package.project

    @tags = @package.tags.where("taggings.user_id = ?", user.id).order(:name)
    if do_render
      render partial: "tags"
    else
      return @tags
    end
  end

  def most_popular_tags
  end

  def most_recent_tags
  end

  # TODO helper function, delete me
  def get_taglist
    tags = Tag.order(:name)
    tags
  end

  def project_tags
    # get project name from the URL
    project_name = params[:project]
    if request.get?
      @project = Project.get_by_name( project_name )
      logger.debug "GET REQUEST for project_tags. User: #{@user}"
      @type = "project"
      @name = params[:project]
      @tags = @project.tags.group(:name).order(:name)
      render partial: "tags"

    elsif request.put?

      @project = Project.get_by_name( project_name )
      logger.debug "Put REQUEST for project_tags. User: #{@http_user.login}"

      # TODO Permission needed!

      if !@http_user
        logger.debug "No user logged in."
        render_error( message: "No user logged in.", status: 403 )
        return
      else
        @tagCreator = @http_user
      end
      # get the taglist xml from the put request
      request_data = request.raw_post
      # taglistXML = "<the whole xml/>"
      @taglistXML = request_data

      # update_tags_by_project_and_user(request_data)

      @tags =  taglistXML_to_tags(request_data)

      save_tags(@project, @tagCreator, @tags)

      logger.debug "PUT REQUEST for project_tags."
      render_ok
    end
  end

  def package_tags
    project_name = params[:project]
    package_name = params[:package]
    if request.get?
      @project = Project.get_by_name( project_name )
      @package = @project.packages.find_by_name package_name

      logger.debug "[TAG:] GET REQUEST for package_tags. User: #{@user}"

      @type = "package"
      @tags = @package.tags.group(:name)
      render partial: "tags"

    elsif request.put?
      logger.debug "[TAG:] PUT REQUEST for package_tags."
      @project = Project.get_by_name( project_name )
      @package = Package.find_by_db_project_id_and_name( @project.id, package_name )

      # TODO Permission needed!

      if !@http_user
        logger.debug "No user logged in."
        render_error( message: "No user logged in.", status: 403 )
        return
      else
        @tagCreator = @http_user
      end
      # get the taglist xml from the put request
      request_data = request.raw_post
      # taglistXML = "<the whole xml/>"
      @taglistXML = request_data

      @tags =  taglistXML_to_tags(request_data)

      save_tags(@package, @tagCreator, @tags)

      render_ok

    end
  end

  def update_tags_by_object_and_user
    @user = User.find_by_login!(params[:user])
    unless @user == @http_user
      render_error status: 403, errorcode: 'permission_denied',
        message: "Editing tags for another user than the logged on user is not allowed."
      return
    end

    @project = Project.get_by_name(params[:project])

    tags, unsaved_tags = taglistXML_to_tags(request.raw_post)

    tag_hash = {}
    tags.each do |tag|
      tag_hash[tag.name] = ""
    end
    logger.debug "[TAG:] Hash of new tags: #{@tag_hash.inspect}"

    if params[:package]
      logger.debug "[TAG:] Package selected"
      @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_project_links: false)

      old_tags = get_tags_by_user_and_package( false )
      old_tags.each do |old_tag|
        unless tag_hash.has_key? old_tag.name
          Tagging.where("user_id = #{@user.id} AND taggable_id = #{@package.id} AND taggable_type = 'Package' AND tag_id = #{old_tag.id}").delete_all
        end
      end
      save_tags(@package, @user, tags)
    else
      logger.debug "[TAG:] Project selected"
      old_tags = get_tags_by_user_and_project( false )
      old_tags.each do |old_tag|
        unless tag_hash.has_key? old_tag.name
          Tagging.where("user_id = #{@user.id} AND taggable_id = #{@project.id} AND taggable_type = 'Project' AND tag_id = #{old_tag.id}").delete_all
        end
      end
      save_tags(@project, @user, tags)
    end

    if !unsaved_tags
      render_ok
    else
      error = "[TAG:] There are rejected Tags: #{unsaved_tags.inspect}"
      logger.debug "#{error}"
      # need exception handling in the tag client
      render_error status: 400, errorcode: 'tagcreation_error',
      message: error
    end
  end

  def taglistXML_to_tags(taglistXML)
    taglist = []

    xml = Xmlhash.parse(taglistXML)

    xml.elements("tag") do  |tag|
      taglist << tag["name"]
    end

    # make tag objects
    tags = []
    taglist.each do |tagname|
      begin
        tags << s_to_tag(tagname)

      rescue RuntimeError => error
        @unsaved_tags ||= []
        @unsaved_tags << tagname
        logger.debug "[TAG:] #{error}"
      end
    end

    [tags, @unsaved_tags]
  end

  def save_tags(object, tagCreator, tags)
    if tags.kind_of? Tag
      tags = [tags]
    end
    tags.each do |tag|
      begin
        create_relationship(object, tagCreator, tag)
      rescue ActiveRecord::StatementInvalid
        logger.debug "The relationship #{object.name} - #{tag.name} - #{tagCreator.login} already exist."
      end
    end
  end

  # create an entry in the join table (taggings) if necessary
  def create_relationship(object, tagCreator, tag)
    Tagging.transaction do
        @jointable = Tagging.new()
        object.taggings << @jointable
        tagCreator.taggings << @jointable
        tag.taggings << @jointable
        @jointable.save
    end
  end

  # get the tag as object
  def s_to_tag(tagname)
    tag = Tag.find_by_name(tagname)
    unless tag
      tag = Tag.create(name: tagname)
    end
    raise RuntimeError.new( "Tag #{tagname} could not be saved. ERROR: #{tag.errors[:name]}" ) unless tag.valid?
    tag
  end

  def tag_error(params)
    render_error status: 404, errorcode: 'unknown_tag',
    message: "Unknown tag #{params[:tag]}"
  end
end
