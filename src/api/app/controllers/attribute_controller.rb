class AttributeController < ApplicationController
  include ValidationHelper

  validate_action index: { method: :get, response: :directory }
  validate_action namespace_definition: { method: :get, response: :attribute_namespace_meta }
  validate_action namespace_definition: { method: :delete, response: :status }
  validate_action namespace_definition: { method: :put, request: :attribute_namespace_meta, response: :status }
  validate_action namespace_definition: { method: :post, request: :attribute_namespace_meta, response: :status }
  validate_action attribute_definition: { method: :get, response: :attrib_type }
  validate_action attribute_definition: { method: :delete, response: :status }
  validate_action attribute_definition: { method: :put, request: :attrib_type, response: :status }
  validate_action attribute_definition: { method: :post, request: :attrib_type, response: :status }

  def index
    if params[:namespace]
      an = AttribNamespace.where(name: params[:namespace]).first
      unless an
        render_error status: 400, errorcode: 'unknown_namespace',
          message: "Attribute namespace does not exist: #{params[:namespace]}"
        return
      end
      list = an.attrib_types.pluck(:name)
    else
      list = AttribNamespace.pluck(:name)
    end

    builder = Builder::XmlMarkup.new(indent: 2)
    xml = builder.directory(count: list.length) do |dir|
      list.each do |a|
        dir.entry(name: a)
      end
    end

    render xml: xml
  end

  # /attribute/:namespace/_meta
  def namespace_definition
    if params[:namespace].nil?
      raise MissingParameterError, "parameter 'namespace' is missing"
    end
    namespace = params[:namespace]

    if request.get?
      @an = AttribNamespace.where(name: namespace).select(:id, :name).first
      unless @an
        render_error message: "Unknown attribute namespace '#{namespace}'",
          status: 404, errorcode: "unknown_attribute_namespace"
      end
      return
    end

    # namespace definitions must be managed by the admin
    return unless extract_user
    unless User.current.is_admin?
      render_error status: 403, errorcode: 'permissions denied',
        message: "Namespace changes are only permitted by the administrator"
      return
    end

    if request.post? || request.put?
      logger.debug "--- updating attribute namespace definitions ---"

      xml_element = Xmlhash.parse(request.raw_post)

      unless xml_element['name'] == namespace
        render_error status: 400, errorcode: 'illegal_request',
          message: "Illegal request: PUT/POST #{request.path}: path does not match content"
        return
      end

      db = AttribNamespace.where(name: namespace).first
      if db
        logger.debug "* updating existing attribute namespace"
        db.update_from_xml(xml_element)
      else
        logger.debug "* create new attribute namespace"
        AttribNamespace.create(name: namespace).update_from_xml(xml_element)
      end

      logger.debug "--- finished updating attribute namespace definitions ---"
      render_ok
    elsif request.delete?
      AttribNamespace.where(name: namespace).destroy_all
      render_ok
    else
      render_error status: 400, errorcode: 'illegal_request',
        message: "Illegal request: POST #{request.path}"
    end
  end

  # /attribute/:namespace/:name/_meta
  def attribute_definition
    if params[:namespace].nil?
      raise MissingParameterError, "parameter 'namespace' is missing"
    end
    if params[:name].nil?
      raise MissingParameterError, "parameter 'name' is missing"
    end
    namespace = params[:namespace]
    name = params[:name]
    ans = AttribNamespace.where(name: namespace).first
    unless ans
      render_error status: 400, errorcode: 'unknown_attribute_namespace',
        message: "Specified attribute namespace does not exist: '#{namespace}'"
      return
    end

    if request.get?
      @at = ans.attrib_types.find_by(name: name)
      unless @at
        render_error message: "Unknown attribute '#{namespace}':'#{name}'",
          status: 404, errorcode: "unknown_attribute"
      end
      return
    end

    # permission check via User model
    return unless extract_user

    if request.post? || request.put?
      logger.debug "--- updating attribute type definitions ---"

      xml_element = Xmlhash.parse(request.raw_post)

      unless xml_element && xml_element['name'] == name && xml_element['namespace'] == namespace
        render_error status: 400, errorcode: 'illegal_request',
          message: "Illegal request: PUT/POST #{request.path}: path does not match content"
        return
      end

      entry = ans.attrib_types.where("name = ?", name).first

      if entry
        authorize entry, :update?

        db = AttribType.find(entry.id) # get a writable object
        logger.debug "* updating existing attribute definitions"
        db.update_from_xml(xml_element)
      else
        entry = AttribType.new(name: name, attrib_namespace: ans)
        authorize entry, :create?

        logger.debug "* create new attribute definition"
        entry.update_from_xml(xml_element)
      end

      logger.debug "--- finished updating attribute namespace definitions ---"
      #--- end update attribute namespace definitions ---#

      render_ok
    elsif request.delete?
      at = ans.attrib_types.where("name = ?", name).first

      if at
        authorize at, :destroy?
        at.destroy
      end

      render_ok
    else
      render_error status: 400, errorcode: 'illegal_request',
        message: "Illegal request: POST #{request.path}"
    end
  end

  class RemoteProject < APIException
    setup 400, "Attribute access to remote project is not yet supported"
  end

  class InvalidAttribute < APIException
  end

  # GET
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def show_attribute
    find_attribute_container

    # init
    # checks
    # exec
    if params[:rev] || @attribute_container.nil?
      # old or remote instance entry
      render xml: Backend::Api::Sources::Package.attributes(params[:project], params[:package], params[:rev])
      return
    end

    render xml: @attribute_container.render_attribute_axml(params)
  end

  # DELETE
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def delete_attribute
    find_attribute_container

    # init
    if params[:namespace].blank? || params[:name].blank?
      render_error status: 400, errorcode: "missing_attribute",
                   message: "No attribute got specified for delete"
      return
    end
    ac = @attribute_container.find_attribute(params[:namespace], params[:name], @binary)

    # checks
    unless ac
      render_error(status: 404, errorcode: "not_found",
                   message: "Attribute #{params[:attribute]} does not exist") && return
    end
    unless User.current.can_create_attribute_in? @attribute_container, namespace: params[:namespace], name: params[:name]
      render_error status: 403, errorcode: "change_attribute_no_permission",
                   message: "user #{user.login} has no permission to change attribute"
      return
    end

    # exec
    ac.destroy
    @attribute_container.write_attributes(params[:comment])
    render_ok
  end

  # POST
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def cmd_attribute
    find_attribute_container

    # init
    req = ActiveXML::Node.new(request.raw_post)

    # checks
    req.each('attribute') do |attr|
      attrib_type = AttribType.find_by_namespace_and_name!(attr.value("namespace"), attr.value("name"))
      attrib = Attrib.new(attrib_type: attrib_type)

      attr.each("value") do |value|
        attrib.values.new(value: value.text)
      end

      attrib.container = @attribute_container

      unless attrib.valid?
        raise APIException, { message: attrib.errors.full_messages.join('\n'), status: 400 }
      end

      authorize attrib, :create?
    end

    # exec
    changed = false
    req.each('attribute') do |attr|
      changed = true if @attribute_container.store_attribute_axml(attr, @binary)
    end
    logger.debug "Attributes for #{@attribute_container.class} #{@attribute_container.name} changed, writing to backend" if changed
    @attribute_container.write_attributes(params[:comment]) if changed
    render_ok
  end

  protected

  before_action :require_valid_project_name, only: [:find_attribute_container]

  def find_attribute_container
    # init and validation
    #--------------------
    params[:user] = User.current.login if User.current
    @binary = nil
    @binary = params[:binary] if params[:binary]
    # valid post commands
    if params[:package] && params[:package] != "_project"
      @attribute_container = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
    else
      # project
      if Project.is_remote_project?(params[:project])
        raise RemoteProject
      end
      @attribute_container = Project.get_by_name(params[:project])
    end

    # is the attribute type defined at all ?
    return if params[:attribute].blank?

    # Valid attribute
    aname = params[:attribute]
    name_parts = aname.split(/:/)
    if name_parts.length != 2
      raise InvalidAttribute, "attribute '#{aname}' must be in the $NAMESPACE:$NAME style"
    end
    # existing ?
    AttribType.find_by_name!(params[:attribute])
    # only needed for a get request
    params[:namespace] = name_parts[0]
    params[:name] = name_parts[1]
  end
end
