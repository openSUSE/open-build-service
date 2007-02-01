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
      if params[:alltags]
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
      logger.debug "TAG: getting  tag cloud from API."
      tagcloud = Tagcloud.new( :tagcloud => session[:tagcloud],
                               :user => @session[:login] )
      
      tagcloud    
    end
                
  def list_objects_by_tag
    @collection = Collection.find(:tag, :type => "_all", :tagname => params[:tag])
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
    save_tags(:user => @session[:login], :project => params[:project], :package => params[:package], :tag => params[:tags])
    @object = Tag.find(:user => @session[:login], :project => params[:project], :package => params[:package])    
    render :partial => "tags_ajax"
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


  def save_tags(params)
    tag = params[:tag] if params[:tag]
    tag =  params[:tags] if params[:tags]
    @tag = Tag.new(:user => params[:user], :project => params[:project], :package => params[:package], :tag => tag)
    @tag.save
  end
  
  
end
