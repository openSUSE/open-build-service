require "rexml/document"

class AttributeController < ApplicationController
  validate_action :index => :directory, :attributelist => :directory
  validate_action :attribute => :attribute
 
  def index
    if params[:namespace]
      list = AttribType.list_all( params[:namespace] )
    else
      list = AttribNamespace.list_all
    end

    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.directory( :count => list.length ) do |dir|
      list.each do |a|
        dir.entry( :name => a.name )
      end
    end

    render :text => xml, :content_type => "text/xml"
  end

  def attributelist
    render :text => AttribType.list_all(:namespace), :content_type => "text/xml"
  end

  # /attribute/:namespace/_meta
  def namespace_definition
    if params[:namespace].nil?
      render_error :status => 400, :errorcode => 'missing_parameter',
        :message => "parameter 'namespace' is missing"
      return
    end
    namespace = params[:namespace]

    if request.get?
      an = AttribNamespace.find_by_name( namespace )
      if an
        render :text => an.render_axml, :content_type => 'text/xml'
      else
        render_error :message => "Unknown attribute namespace '#{namespace}'",
          :status => 404, :errorcode => "unknown_attribute_namespace"
      end
      return
    end

    # namespace definitions must be managed by the admin
    unless extract_user and @http_user.is_admin?
      render_error :status => 400, :errorcode => 'permissions denied',
        :message => "Namespace changes are only permitted by the administrator"
      return
    end

    if request.post?
      logger.debug "--- updating attribute namespace definitions ---"

      xml = REXML::Document.new( request.raw_post )
      xml_element = xml.elements["/namespace"] if xml

      unless xml and xml_element and xml_element.attributes['name'] == namespace
        render_error :status => 400, :errorcode => 'illegal_request',
          :message => "Illegal request: POST #{request.path}: path does not match content"
        return
      end

      db = AttribNamespace.find_by_name(namespace)
      if db
          logger.debug "* updating existing attribute namespace"
          db.update_from_xml(xml_element)
      else
          logger.debug "* create new attribute namespace"
          AttribNamespace.create(:name => namespace).update_from_xml(xml_element)
      end

      logger.debug "--- finished updating attribute namespace definitions ---"
      render_ok
    elsif request.delete?
      db = AttribNamespace.find_by_name(namespace)
      db.destroy
      render_ok
    else
      render_error :status => 400, :errorcode => 'illegal_request',
        :message => "Illegal request: POST #{request.path}"
    end
  end

  # /attribute/:namespace/:name/_meta
  def attribute_definition
    if params[:namespace].nil?
      render_error :status => 400, :errorcode => 'missing_parameter',
        :message => "parameter 'namespace' is missing"
      return
    end
    if params[:name].nil?
      render_error :status => 400, :errorcode => 'missing_parameter',
        :message => "parameter 'name' is missing"
      return
    end
    namespace = params[:namespace]
    name = params[:name]
    ans = AttribNamespace.find_by_name namespace
    unless ans
       render_error :status => 400, :errorcode => 'unknown_attribute_namespace',
         :message => "Specified attribute namespace does not exist: '#{namespace}'"
       return
    end

    if request.get?
      at = AttribType.find( :first, :joins => ans, :conditions=>{:name=>name} )
      if at
        render :text => at.render_axml, :content_type => 'text/xml'
      else
        render_error :message => "Unknown attribute '#{namespace}':'#{name}'",
          :status => 404, :errorcode => "unknown_attribute"
      end
      return
    end

    # FIXME: permission check should check the modifiable_by, just for admin for noww
    unless extract_user and @http_user.is_admin?
      render_error :status => 400, :errorcode => 'permissions denied',
        :message => "Attribute type changes are only permitted by the administrator"
      return
    end

    if request.post?
      logger.debug "--- updating attribute type definitions ---"

      xml = REXML::Document.new( request.raw_post )
      xml_element = xml.elements["/attribute"] if xml

      unless xml and xml_element and xml_element.attributes['name'] == name and xml_element.attributes['namespace'] == namespace
        render_error :status => 400, :errorcode => 'illegal_request',
          :message => "Illegal request: POST #{request.path}: path does not match content"
        return
      end

      entry = AttribType.find( :first, :joins => ans, :conditions=>{:name=>name} )
      if entry
          db = AttribType.find_by_id( entry.id ) # get a writable object
          logger.debug "* updating existing attribute definitions"
          db.update_from_xml(xml_element)
      else
          logger.debug "* create new attribute definition"
          AttribType.new(:name => name, :attrib_namespace => ans).update_from_xml(xml_element)
      end

      logger.debug "--- finished updating attribute namespace definitions ---"
      #--- end update attribute namespace definitions ---#

      render_ok
    elsif request.delete?
      at = AttribType.find( :first, :joins => ans, :conditions=>{:name=>name} )
      at.destroy
      render_ok
    else
      render_error :status => 400, :errorcode => 'illegal_request',
        :message => "Illegal request: POST #{request.path}"
    end
  end

end
