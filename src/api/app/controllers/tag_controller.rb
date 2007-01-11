include REXML


class TagController < ApplicationController    
  
  #list all available tags as xml list
  def list_xml
    @taglist = Tag.find(:all)
    render :partial => "listxml"
  end
  
  def get_tags_by_owner
    #TODO use it! or delete it.
    @http_user = "Admin"
    @owner = User.find_by_login(@http_user)
    @tags = @owner.tags
    #render :text => "#{@tags}"
  end
  
  def get_projects_by_tag
    @tag = Tag.find_by_name(params[:tag])
    @projects = @tag.db_projects
    render :partial => "objects_by_tag"
  end
  
  def get_packages_by_tag
    @tag = Tag.find_by_name(params[:tag])
    @packages = @tag.db_packages
    render :partial => "objects_by_tag"
  end
  
  def get_objects_by_tag
    @tag = Tag.find_by_name(params[:tag])
    
    @projects = @tag.db_projects
    @packages = @tag.db_packages
    render :partial => "objects_by_tag"
  end
  
  def most_popular_tags()
  end
  
  def most_recent_tags()
  end 
  
  
    def tag_cloud 
      @steps = (params[:steps] ||= 6).to_i
      @distribution_method = (params[:distribution] ||= "linear")
      @user_only = params[:user_only]
      
      raise ArgumentError,"Number of font sizes used in the tag cloud must be set." if not @steps
      
      if params[:user_only] == "true"
        @tags = @http_user.tags.find(:all, :group => "name")
      else
        @tags = Tag.find(:all)
      end
      
      case @distribution_method
        when "linear"
          @thresholds = linear_distribution_method(@tags,@steps)
        when "logarithmic"
          @thresholds = logarithmic_distribution_method(@tags,@steps)      
        when "raw"
          #nothing to do
        else
          raise ArgumentError,"Unknown font size distribution type. Use linear or logarithmic."
      end
      render :partial => "tagcloud"
    end
  
  #TODO helper function, delete me
  def get_taglist
    tags = Tag.find(:all)
    return tags
  end
  
  def get_max_min_delta(taglist,steps)
    max, min = taglist[0].weight, taglist[0].weight
    delta = 0
    
    taglist.each do |tag|
      max = tag.weight if tag.weight > max
      min = tag.weight if tag.weight < min
    end
    
    if max != min
      delta = (max - min) / steps.to_f
    else
      delta = (max) / steps.to_f
    end
    return max, min, delta
  end
  
  def linear_distribution_method(taglist, steps)
    max, min, delta = get_max_min_delta(taglist,steps)
    @thresholds = []
    for i in 1..steps
      size = i
      @thresholds << min + size * delta
    end
    return @thresholds  
  end
  private :linear_distribution_method
  
  def logarithmic_distribution_method(taglist, steps)
    max, min, delta = get_max_min_delta(taglist,steps)
    @thresholds = []
    for i in 1..steps
      size = i
      @thresholds << 100 * Math.log(min + size * delta + 2)
    end
    return @thresholds
  end
  private :logarithmic_distribution_method
  
  
  def project_tags 
    #get project name from the URL
    project_name = params[:project]
    
    if request.get?
      @project = DbProject.find_by_name( project_name )
      logger.debug "GET REQUEST for project_tags. User: #{@user}"
      @type = "project" 
      @name = params[:project]
      @tags = @project.tags
      render :partial => "tags"
      
    elsif request.put?
      
      @project = DbProject.find_by_name( project_name )
      logger.debug "Put REQUEST for project_tags. User: #{@http_user.login}" 
      
      #TODO Permission needed!
      
      if !@http_user 
        logger.debug "No user logged in."
        render_error( :message => "No user logged in.", :status => 403 )
        return
      else
        @tagCreator = @http_user
      end
      #get the taglist xml from the put request
      request_data = request.raw_post
      #taglistXML = "<the whole xml/>"
      @taglistXML = request_data
      
      @tags =  taglistXML_to_tags(request_data)
      
      save_tags(@project, @tagCreator, @tags)
      
      logger.debug "PUT REQUEST for project_tags."     
      render :nothing => true, :status => 200
    end 
  end
  
  #TODO: dummy function for tags
  def package_tags
    
    project_name = params[:project]
    package_name = params[:package]
    
    if request.get?
      
      @project = DbProject.find_by_name( project_name )
      @package = DbPackage.find_by_db_project_id_and_name( @project.id, package_name )
      
      logger.debug "GET REQUEST for package_tags. User: #{@user}"
      
      @type = "package" 
      #@name = params[:project]
      #@packagename = params[:package]
      @tags = @package.tags
      render :partial => "tags"
      
      
    elsif request.put?
      logger.debug "PUT REQUEST for package_tags."
      @project = DbProject.find_by_name( project_name )
      @package = DbPackage.find_by_db_project_id_and_name( @project.id, package_name )
      
      #TODO Permission needed!
      
      if !@http_user 
        logger.debug "No user logged in."
        render_error( :message => "No user logged in.", :status => 403 )
        return
      else
        @tagCreator = @http_user
      end
      #get the taglist xml from the put request
      request_data = request.raw_post
      #taglistXML = "<the whole xml/>"
      @taglistXML = request_data
      
      @tags =  taglistXML_to_tags(request_data)
      
      save_tags(@package, @tagCreator, @tags)
      
      render :nothing => true, :status => 200
      
      
    end
  end
  
  
  
  def taglistXML_to_tags(taglistXML)
    taglist = []
    
    xml = REXML::Document.new(taglistXML)
    
    xml.root.get_elements("tag").each do  |tag| 
      taglist << tag.attributes.get_attribute("name").value
    end
    
    #make tag objects
    tags = []
    taglist.each do |tagname|
      tags << s_to_tag(tagname)
    end 
    
    return tags
  end
  
  def save_tags(object, tagCreator, tags)
    if tags.kind_of? Tag then
      tags = [tags]
    end  
    tags.each do |tag|
      create_relationship(object, tagCreator, tag)
    end      
  end
  
  #create an entry in the join table (taggings) if necessary
  def create_relationship(object, tagCreator, tag)
    begin 
      Tagging.transaction do
        @jointable = Tagging.new()
        object.taggings << @jointable
        tagCreator.taggings << @jointable
        tag.taggings << @jointable
        @jointable.save
      end  
    rescue ActiveRecord::StatementInvalid
      logger.debug "The relationship #{object.name} - #{tag.name} - #{tagCreator.login} already exist."
    end  
  end
  
  #get the tag as object
  def s_to_tag(tagname)
    tag = Tag.find_or_create_by_name(tagname)
    return tag
  end
  
end
