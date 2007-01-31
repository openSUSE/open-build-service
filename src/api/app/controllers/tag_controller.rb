include REXML


class TagController < ApplicationController    
  
  #list all available tags as xml list
  def list_xml
    @taglist = Tag.find(:all)
    render :partial => "listxml"
  end

  def get_tagged_objects_by_user
    
  end

  def get_tagged_projects_by_user
    user = @http_user
    @taggings = Tagging.find(:all,
                             :conditions => ["taggable_type = ? AND user_id = ?","DbProject",user.id])
    @projects_tags = {}
    @taggings.each do |tagging|
      project = DbProject.find(tagging.taggable_id)
      tag = Tag.find(tagging.tag_id)
      @projects_tags[project] = [] if @projects_tags[project] == nil
      @projects_tags[project] <<  tag
    end
    @projects_tags.keys.each do |key|
      @projects_tags[key].sort!{ |a,b| a.name.downcase <=> b.name.downcase }
    end
    @my_type = "project"
    render :partial => "tagged_objects_with_tags"
  end


  def get_tagged_packages_by_user
    user = @http_user
    @taggings = Tagging.find(:all,
                             :conditions => ["taggable_type = ? AND user_id = ?","DbPackage",user.id])
    @packages_tags = {}
    @taggings.each do |tagging|
      package = DbPackage.find(tagging.taggable_id)
      tag = Tag.find(tagging.tag_id)
      @packages_tags[package] = [] if @packages_tags[package] == nil
      @packages_tags[package] <<  tag
    end
    @packages_tags.keys.each do |key|
      @packages_tags[key].sort!{ |a,b| a.name.downcase <=> b.name.downcase }
    end
    @my_type = "package"
    render :partial => "tagged_objects_with_tags"
  end


  def get_tags_by_user
    @user = @http_user
    @tags = @user.tags.find(:all, :group => "name")
    @tags
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

  def get_tags_by_user_and_project( do_render=true )
    user = @http_user
    @type = "project"
    @name = params[:project]
    @project = DbProject.find_by_name(params[:project])
    @tags = @project.tags.find(:all, :order => :name, :conditions => ["taggings.user_id = ?",user.id])
    if do_render
      render :partial => "tags"
    else
      return @tags
    end
  end

  
  def get_tags_by_user_and_package( do_render=true  )
    user = @http_user
    @type = "package"
    @project = DbProject.find_by_name(params[:project])
    @name = params[:package]
    @package = @project.db_packages.find_by_name(params[:package])
    @tags = @package.tags.find(:all, :order => :name, :conditions => ["taggings.user_id = ?",user.id])
    if do_render
      render :partial => "tags"
    else
      return @tags
    end
  end

 
  def most_popular_tags()
  end
 
  
  def most_recent_tags()
  end     


    def tagcloud 
      @steps = (params[:steps] ||= 6).to_i
      @distribution_method = (params[:distribution] ||= "linear")
      
      raise ArgumentError,"Number of font sizes used in the tag cloud must be set." if not @steps
      
      if params[:user]
        @tags = get_tags_by_user
      else
        @tags = Tag.find(:all, :order => :name)
      end
    
      #the case of an empty tagcloud
      if @tags == [] 
        render :partial => "tagcloud"
        return
      end
      
      #chooses the distribution method, how tags will be scaled
      case @distribution_method
        when "linear"
          @thresholds = linear_distribution_method(@tags,@steps)
        when "logarithmic"
          @thresholds = logarithmic_distribution_method(@tags,@steps)      
        when "raw"
          #nothing to do
        else
          raise render_error :status => 400, :errorcode => 'unknown_distribution_method_error',
            :message => "Unknown font size distribution type. Use linear or logarithmic."
       end
      render :partial => "tagcloud"
    end


  #TODO helper function, delete me
  def get_taglist
    tags = Tag.find(:all, :order => :name)
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
      @tags = @project.tags.find(:all, :group => "name", :order => :name)
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
      
      #update_tags_by_project_and_user(request_data)
      
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
      @tags = @package.tags.find(:all, :group => "name")
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


  def update_tags_by_object_and_user
    
    @user = @http_user
    @project = DbProject.find_by_name(params[:project])
    
    tags = taglistXML_to_tags(request.raw_post)
    
    tag_hash = {}
    tags.each do |tag|
      tag_hash[tag.name] = ""
    end
    logger.debug "[TAG:] Hash of new tags: #{@tag_hash.inspect}"
    
    if params[:package]
      logger.debug "[TAG:] Package selected"
      @package = @project.db_packages.find_by_name(params[:package])
      #Holzhammermethode ;)
      #Tagging.delete_all("user_id = #{@user.id} AND taggable_id = #{@package.id} AND taggable_type = 'DbPackage'")

      old_tags = get_tags_by_user_and_package( false )
      old_tags.each do |old_tag|
      unless tag_hash.has_key? old_tag.name
          Tagging.delete_all("user_id = #{@user.id} AND taggable_id = #{@package.id} AND taggable_type = 'DbPackage' AND tag_id = #{old_tag.id}")
        end
      end
      save_tags(@package,@user,tags)
    else
      logger.debug "[TAG:] Project selected"
      #Holzhammermethode ;)
      #Tagging.delete_all("user_id = #{@user.id} AND taggable_id = #{@project.id} AND taggable_type = 'DbProject'")
      old_tags = get_tags_by_user_and_project( false )
      old_tags.each do |old_tag|
        unless tag_hash.has_key? old_tag.name
          Tagging.delete_all("user_id = #{@user.id} AND taggable_id = #{@project.id} AND taggable_type = 'DbProject' AND tag_id = #{old_tag.id}")
        end
      end
      save_tags(@project,@user,tags)
    end    
    render :nothing => true, :status => 200
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
  private :save_tags
  
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
  private :s_to_tag

  
end
