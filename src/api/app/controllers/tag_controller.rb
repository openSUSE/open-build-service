include REXML


class TagController < ApplicationController    
  
  #list all available tags as xml list
  def list_xml
    @taglist = Tag.find(:all)
    render :partial => "listxml"
  end


   def get_tags_on_object(object)
      @tags = object.tags
      return tags
   end
   
   #TODO make it more generic 
   def get_objects_on_tag(tag)
      @tag = Tag.find_by_name(tag)
      @objects = tag.projects
      #TODO add tag.packages ... or more
      return @objects
   end

   def most_popular_tags()
   end
  
   def most_recent_tags()
   end 
  
   #this function ist only a proto type.
   def tag_cloud
      max = 0
      min = 0
      @tags = Tag.find(:all)
       
      first_run = true
      
      @tags.each do |tag|
        tag.weight
        
        if first_run then 
          min = tag.weight
          max = tag.weight
          first_run = false
        end
        
        if tag.weight > max then
          max = tag.weight
        end
        if tag.weight < min then
          min = tag.weight
        end
        
      end
      logger.debug "Tag cloud max: #{max} min: #{min}"
      render :partial => "tagcloud"
      
   end

   
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
    #project_name = params[:project]
    #package_name = params[:package]
  
    if request.get?
      logger.debug "GET REQUEST for package_tags."
    elsif request.put?
      logger.debug "PUT REQUEST for package_tags."
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
