

class TagController < ApplicationController    
  
  validate_action :tags_by_user_and_object => :tags
  validate_action :project_tags => :tags
  validate_action :package_tags => :tags
  
  
  #list all available tags as xml list
  def list_xml
    @taglist = Tag.find(:all)
    render :partial => "listxml"
  end
  private :list_xml
  
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
    begin
      @tag = Tag.find_by_name(params[:tag])
      @projects = @tag.db_projects.find(:all, :group => "name", :order => "name")
       
      render :partial => "objects_by_tag"
      
    rescue
      #raise unless ( RAILS_ENV ==  'production' ) 
      if @tag.nil?
        tag_error(:tag => params[:tag])
      elsif
        raise
      end
    end
  end
  
  
  def get_packages_by_tag
    begin
      @tag = Tag.find_by_name(params[:tag])
      @packages = @tag.db_packages(:all, :group => "name", :order => "name")
      
      render :partial => "objects_by_tag"
      
      
    rescue
      if @tag.nil?
        tag_error(:tag => params[:tag])
      elsif
        raise 
      end
    end
  end
  
  
  def get_objects_by_tag
    begin
      @tag = Tag.find_by_name(params[:tag])
      @projects = @tag.db_projects.find(:all, :group => "name", :order => "name")
      @packages = @tag.db_packages.find(:all, :group => "name", :order => "name")
      render :partial => "objects_by_tag"
      
      
    rescue
      if @tag.nil?
        tag_error(:tag => params[:tag])
      elsif
        raise
      end
    end
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
    begin
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
      
      
    rescue
      if @project.nil?
        render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{params[:project]}"
      end
    end 
  end
  
  
  def get_tags_by_user_and_package( do_render=true  )
    user = @http_user
    @type = "package" 
    
    begin
      @project = DbProject.find_by_name(params[:project]) 
      @name = params[:package]
      @package = @project.db_packages.find_by_name(params[:package])
      @tags = @package.tags.find(:all, :order => :name, :conditions => ["taggings.user_id = ?",user.id])
      if do_render
        render :partial => "tags"
      else
        return @tags
      end
      
      
    rescue
      if @project.nil?
        render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{params[:project]}" 
      elsif @package.nil?   
        render_error :status => 404, :errorcode => 'unknown_package',
        :message => "Unknown package #{params[:package]}"   
      end
    end
  end
  
  
  def most_popular_tags()
  end
  
  
  def most_recent_tags()
  end     
  
  
  def tagcloud 
    allowed_distribution_methods = ['raw', 'linear' , 'logarithmic']
    
    begin 
      @steps = (params[:steps] ||= 6).to_i
      raise ArgumentError.new "Invalid value for parameter steps.
                     (must be 1..100)" if @steps < 1 or @steps > 100
      
      @distribution_method = (params[:distribution] ||= "linear")
      raise ArgumentError.new "Invalid value for parameter distribution. 
   	    (distribution=#{@distribution_method})" if not allowed_distribution_methods.include? @distribution_method
      
      if request.get?
        
        
        if params[:user]
          tagcloud = Tagcloud.new(:scope => "user", :user => @http_user)
        else
          tagcloud = Tagcloud.new(:scope => "global")
        end
        
        #get the list of tags
        @tags = tagcloud.get_tags(@distribution_method,@steps)
        raise ArgumentError.new "tag-cloud generation failed." if @tags.nil?
        
        render :partial => "tagcloud"
        
      elsif request.post?
        request_data = request.raw_post
        logger.debug "[TAG:] Tag cloud post: #{request_data}"
        collection = ActiveXML::Node.new( request_data )
        projects =[]
        collection.each_project do |project|
          proj = DbProject.find_by_name(project.name)
          logger.debug '[TAG:] AAAAAAAAAAAAAAAA #{proj.inspect}'
          raise RuntimeError.new "Error: Project '#{project.name}' not found." unless proj
          projects << proj
        end
        logger.debug "[TAG:] Projects: #{projects.inspect}"
        
        packages = []
        collection.each_package do |package|
          project = DbProject.find_by_name(package.project)
          raise RuntimeError.new "Error: Project '#{package.project}' not found." unless project
          pack = DbPackage.find_by_db_project_id_and_name( project.id, package.name )
          raise RuntimeError.new "Error: Package '#{package.name}' not found." unless pack
          packages << pack
        end
        logger.debug "[TAG:] Packages: #{packages.inspect}"
        
        objects = projects + packages
        tagcloud = Tagcloud.new(:scope => 'by_given_objects', :objects => objects)
        logger.debug "[TAG:] Tagcloud: #{tagcloud.inspect}"
        #@distribution_method = 'linear'
        @tags = tagcloud.get_tags(@distribution_method,6)
        logger.debug "[TAG:] tagcloud tags: #{@tags}"
        render :partial => 'tagcloud'
      end
      
    rescue Exception => error
      render_error :status => 404, :errorcode => 'tagcloud_error',
      :message => error 
    end
    
  end
  
  
  #TODO helper function, delete me
  def get_taglist
    tags = Tag.find(:all, :order => :name)
    return tags
  end
  
  def project_tags 
    #get project name from the URL
    project_name = params[:project]
    begin
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
      
      
    rescue
      if @project.nil?
        render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{params[:project]}" 
      end
    end
  end
  
  
  def package_tags
    
    project_name = params[:project]
    package_name = params[:package]
    begin
      if request.get?
        @project = DbProject.find_by_name( project_name )
        @package = DbPackage.find_by_db_project_id_and_name( @project.id, package_name )
        
        logger.debug "[TAG:] GET REQUEST for package_tags. User: #{@user}"
        
        @type = "package" 
        @tags = @package.tags.find(:all, :group => "name")
        render :partial => "tags"
        
      elsif request.put?
        logger.debug "[TAG:] PUT REQUEST for package_tags."
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
      
      
    rescue
      if @project.nil?
        render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown project #{params[:project]}" 
      elsif @package.nil?
        render_error :status => 404, :errorcode => 'unknown_package',
        :message => "Unknown project #{params[:package]}"
      elsif @tags.nil?
        render_error :status => 404, :errorcode => 'tag_error',
        :message => "Tags couldn't be saved."
      end
    end
    
  end
  
  
  def update_tags_by_object_and_user
    
    @user = @http_user
    @project = DbProject.find_by_name(params[:project])
    
    tags, unsaved_tags = taglistXML_to_tags(request.raw_post)
    
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
    
    if not unsaved_tags
      render :nothing => true, :status => 200
    else  
      error = "[TAG:] There are rejected Tags: #{unsaved_tags.inspect}"
      logger.debug "#{error}"
      #need exception handling in the tag client
      render_error :status => 400, :errorcode => 'tagcreation_error',
      :message => error 
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
    taglist.each do |@tagname|
      begin
        tags << s_to_tag(@tagname)
      
      rescue RuntimeError => error
        @unsaved_tags ||= []
        @unsaved_tags << @tagname
        logger.debug "[TAG:] #{error}" 
      end      
    end 
    
    return tags, @unsaved_tags
  end
  private :taglistXML_to_tags
  
  
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
  private :create_relationship
  
  #get the tag as object
  def s_to_tag(tagname)
    tag = Tag.find_or_create_by_name(tagname)
    raise RuntimeError.new "Tag #{tagname} could not be saved. ERROR: #{tag.errors[:name]}" if not tag.valid?    
    return tag
  end
  private :s_to_tag
  
  
  def tag_error(params)
    render_error :status => 404, :errorcode => 'unknown_tag',
    :message => "Unknown tag #{params[:tag]}" 
  end
  private :tag_error
  
end
