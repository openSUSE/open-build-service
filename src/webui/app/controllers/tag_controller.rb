class TagController < ApplicationController

  def show
    flash[:note] = "Sry, not yet implemented."
    redirect_to :back
  end

  def edit

    @projects, @packages = get_tagged_objects_by_user(@session[:login])
    @tagcloud = get_tagcloud

  end


  def switch_tagcloud
    if params[:hierarchical_browsing]
      logger.debug "Switching to tagcloud view HIERARCHICAL BROWSING..."
      session[:tagcloud] = :hierarchical_browsing

      logger.debug "...done."
    elsif params[:alltags]
      logger.debug "Switching to tagcloud view ALLTAGS..."
      session[:tagcloud] = :alltags

      logger.debug "...done."
    else
      logger.debug "Switching to tagcloud view MYTAGS..."

      session[:tagcloud] = :mytags
      logger.debug "...done."
    end
    @tagcloud = get_tagcloud
    render :partial => "tagcloud_container"
  end


  def get_tagcloud
    session[:tagcloud] ||= :mytags
    logger.debug "TAG: getting  tag cloud from API."
    limit = nil
    if session[:tagcloud] == :mytags
      limit = 0
    end
    tagcloud = Tagcloud.find( session[:tagcloud], :user => session[:login], :limit => limit.to_s)
    return tagcloud
  end


  def list_objects_by_tag
    tagname = CGI::unescape(params[:tag])
    @collection = Collection.find(:tag, :type => "_all", :tagname => tagname )
    @projects = []
    @collection.each_project do |project|
      @projects << project
    end
    @packages = []
    @collection.each_package do |package|
      @packages << package
    end
    # building tag cloud
    @tagcloud = get_tagcloud

    render :action => "list_objects_by_tag"
  end


  # render the input form for tags
  def edit_taglist_form
    user = @session[:login]
    project = params[:project]
    package = params[:package]

    @tags = get_tags_by_user_and_object(:project => project, :package => package, :user => user)

    @taglist = []
    @tags.each_tag do |tag|
      @taglist << tag.name
      @taglist << " "
      logger.debug "TAG: #{tag.name}"
    end
    @tags = @taglist
    render :partial => "edit_taglist_form"
  end


  def edit_taglist_ajax
    if params[:package]
      logger.debug "New tag(s) #{params[:tag]} for project #{params[:project]}, package #{params[:package]}."
    elsif
      logger.debug "New tag(s) #{params[:tag]} for project #{params[:project]}."
    end
    begin

      @tag_xml = Tag.new(:user => @session[:login], :project => params[:project], :package => params[:package], :tag => params[:tags])
      @tag_xml.save

    rescue ActiveXML::Transport::Error => exception
      rescue_action_in_public exception
      @error = CGI::escapeHTML(@message)
      logger.debug "[TAG:] Error: #{@message}"
      @unsaved_tags = true
    end

    @object = Tag.find(:user => @session[:login], :project => params[:project], :package => params[:package])
    @tagcloud = get_tagcloud

    render :action => "edit_taglist_ajax"
  end


  def get_tagged_objects_by_user(user)
    @collection = Collection.find(:tags_by_user, :user => user, :type => "_projects")
    @collection ||= []
    @projects = []
    @collection.each_project do |project|
      @projects << project
    end
    @collection = Collection.find(:tags_by_user, :user => user, :type => "_packages")
    @collection ||= []
    @packages = []
    @collection.each_package do |package|
      @packages << package
    end
    return @projects, @packages
  end


  def get_tags_by_user_and_object(params)
    user = session[:login]
    project = params[:project]
    package = params[:package]
    @tags = Tag.find(:user => user, :project => project, :package => package)
    @tags
  end


  def hierarchical_browsing

    tagname = CGI::unescape(params[:tag])

    if params[:concatenated_tags]
      @concatenated_tags = params[:concatenated_tags].split('::')
    else
      @concatenated_tags = []
    end

    @concatenated_tags << tagname
    @concatenated_tags = @concatenated_tags.uniq.join('::')

    logger.debug "[TAG:] \t CONCATENATED TAGS: \t #{@concatenated_tags}"
    @collection = Collection.find(:tag, :type => "_all", :tagname => @concatenated_tags )

    @projects = []
    @collection.each_project do |project|
    @projects << Project.new(project.data.to_s)
    end

    @packages = []
    @collection.each_package do |package|
    @packages << Package.new(package.data.to_s)
    end

    #logger.debug "\n[TAG: PROJECTS:] /t #{@projects.inspect} \n"
    #logger.debug "\n[TAG: PACKAGES:] /t #{@packages.inspect}\n"

    #@tagcloud = Tagcloud.new( :tagcloud => session[:tagcloud],
    #  :user => session[:login], :projects => @projects, :packages => @packages )



    conditions = conditions_to_xml(:projects => @projects, :packages => @packages)
    @tagcloud = Tagcloud.find( session[:tagcloud], :user => session[:login], :conditions => conditions )

    render :action => "list_objects_by_tag"

    #flash[:error] = 'Sry, this feature is not implemented yet.'
    #redirect_to :back

  end


  def conditions_to_xml(opts)

        xml = REXML::Document.new
        xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
        xml.add_element( REXML::Element.new("collection") )
        #adding a project
        opts[:projects].each do |project|
          element = REXML::Element.new( 'project' )
          element.add_attribute REXML::Attribute.new('name', project.name)
          xml.root.add_element(element)
        end
        #adding a package
        opts[:packages].each do |package|
          element = REXML::Element.new( 'package' )
          element.add_attribute REXML::Attribute.new('project', package.project)
          element.add_attribute REXML::Attribute.new('name', package.name)
          xml.root.add_element(element)
        end

        return xml
  end


end
