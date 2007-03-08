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
      session[:tagcloud] = "hierarchical_browsing"
      
      logger.debug "...done."
    elsif params[:alltags]
      logger.debug "Switching to tagcloud view ALLTAGS..." 
      session[:tagcloud] = "alltags"
      
      logger.debug "...done."
    else
      logger.debug "Switching to tagcloud view MYTAGS..." 
      
      session[:tagcloud] = "mytags"
      logger.debug "...done."
    end
    @tagcloud = get_tagcloud
    render :partial => "tagcloud_container"    
  end
  
  
  def get_tagcloud
    session[:tagcloud] ||= "mytags"
    logger.debug "TAG: getting  tag cloud from API."
    tagcloud = Tagcloud.new( :tagcloud => session[:tagcloud],
                            :user => @session[:login] )
    tagcloud    
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
    
    flash[:error] = 'Sry, this feature is not implemented yet.'
    redirect_to :back
    
  end
  

end
