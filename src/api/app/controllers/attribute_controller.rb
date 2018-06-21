class AttributeController < ApplicationController
  include ValidationHelper

  validate_action index: { method: :get, response: :directory }
  validate_action show_namespace_definition: { method: :get, response: :attribute_namespace_meta }
  validate_action delete_namespace_definition: { method: :delete, response: :status }
  validate_action update_namespace_definition: { method: :put, request: :attribute_namespace_meta, response: :status }
  validate_action update_namespace_definition: { method: :post, request: :attribute_namespace_meta, response: :status }
  validate_action show_attribute_definition: { method: :get, response: :attrib_type }
  validate_action delete_attribute_definition: { method: :delete, response: :status }
  validate_action update_attribute_definition: { method: :put, request: :attrib_type, response: :status }
  validate_action update_attribute_definition: { method: :post, request: :attrib_type, response: :status }
  before_action :require_admin, only: [:update_namespace_definition, :delete_namespace_definition]
  before_action :require_attribute_name, only: [:show_attribute_definition, :update_attribute_definition, :delete_attribute_definition]

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

  def show_namespace_definition
    if (@an = AttribNamespace.where(name: ensure_namespace).select(:id, :name).first)
      render template: 'attribute/namespace_definition'
    else
      render_error message: "Unknown attribute namespace '#{@namespace}'",
        status: 404, errorcode: 'unknown_attribute_namespace'
    end
  end

  def delete_namespace_definition
    AttribNamespace.where(name: ensure_namespace).destroy_all
    render_ok
  end

  # /attribute/:namespace/_meta
  def update_namespace_definition
    xml_element = Xmlhash.parse(request.raw_post)
    ensure_namespace

    unless xml_element['name'] == @namespace
      render_error status: 400, errorcode: 'illegal_request',
        message: "Illegal request: PUT/POST #{request.path}: path does not match content"
      return
    end

    db = AttribNamespace.where(name: @namespace).first
    if db
      db.update_from_xml(xml_element)
    else
      AttribNamespace.create(name: @namespace).update_from_xml(xml_element)
    end

    render_ok
  end

  # GET /attribute/:namespace/:name/_meta
  def show_attribute_definition
    if (@at = attribute_type)
      render template: 'attribute/attribute_definition'
    else
      render_error message: "Unknown attribute '#{@namespace}':'#{@name}'",
                   status: 404, errorcode: 'unknown_attribute'
    end
  end

  # DELETE /attribute/:namespace/:name/_meta
  # DELETE /attribute/:namespace/:name
  def delete_attribute_definition
    if (at = attribute_type)
      authorize at, :destroy?
      at.destroy
    end

    render_ok
  end

  # POST/PUT /attribute/:namespace/:name/_meta
  def update_attribute_definition
    return unless (xml_element = validate_attribute_definition_xml)

    if (entry = attribute_type)
      authorize entry, :update?

      db = AttribType.find(entry.id) # get a writable object
      db.update_from_xml(xml_element)
    else
      create_attribute_definiton(xml_element)
    end

    render_ok
  end

  class RemoteProject < APIException
    setup 400, 'Attribute access to remote project is not yet supported'
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
    if params[:rev] || params[:meta] || params[:view] || @attribute_container.nil?
      # old or remote instance entry
      render xml: Backend::Api::Sources::Package.attributes(params[:project], params[:package], params)
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
      render_error status: 400, errorcode: 'missing_attribute',
                   message: 'No attribute got specified for delete'
      return
    end
    ac = @attribute_container.find_attribute(params[:namespace], params[:name], @binary)

    # checks
    unless ac
      render_error(status: 404, errorcode: 'not_found',
                   message: "Attribute #{params[:attribute]} does not exist") && return
    end
    unless User.current.can_create_attribute_in? @attribute_container, namespace: params[:namespace], name: params[:name]
      render_error status: 403, errorcode: 'change_attribute_no_permission',
                   message: "user #{user.login} has no permission to change attribute"
      return
    end

    # exec
    ac.destroy
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
    req = Xmlhash.parse(request.raw_post)
    # Keep compat exception
    raise ActiveXML::ParseError unless req

    # This is necessary for checking the authorization and do not create the attribute
    # The attribute creation will happen in @attribute_container.store_attribute_xml
    req.elements('attribute') do |attr|
      attrib_type = AttribType.find_by_namespace_and_name!(attr.value('namespace'), attr.value('name'))
      attrib = Attrib.new(attrib_type: attrib_type)

      attr.elements('value') do |value|
        attrib.values.new(value: value)
      end

      attrib.container = @attribute_container

      unless attrib.valid?
        raise APIException, message: attrib.errors.full_messages.join('\n'), status: 400
      end

      authorize attrib, :create?
    end

    # exec
    req.elements('attribute') do |attr|
      @attribute_container.store_attribute_xml(attr, @binary)
    end
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
    if params[:package] && params[:package] != '_project'
      @attribute_container = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
    else
      # project
      raise RemoteProject if Project.is_remote_project?(params[:project])
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

  private

  def ensure_namespace
    if params[:namespace].nil?
      raise MissingParameterError, "parameter 'namespace' is missing"
    end
    @namespace = params[:namespace]
  end

  def require_attribute_namespace
    ensure_namespace
    @ans = AttribNamespace.where(name: @namespace).first
    return true if @ans

    render_error status: 400, errorcode: 'unknown_attribute_namespace',
      message: "Specified attribute namespace does not exist: '#{namespace}'"
    false
  end

  def require_attribute_name
    return unless require_attribute_namespace
    if params[:name].nil?
      raise MissingParameterError, "parameter 'name' is missing"
    end
    @name = params[:name]
  end

  def create_attribute_definiton(xml_element)
    entry = AttribType.new(name: @name, attrib_namespace: @ans)
    authorize entry, :create?

    entry.update_from_xml(xml_element)
  end

  def attribute_type
    @ans.attrib_types.where(name: @name).first
  end

  def validate_attribute_definition_xml
    xml_element = Xmlhash.parse(request.raw_post)

    return xml_element if xml_element && xml_element['name'] == @name && xml_element['namespace'] == @namespace
    render_error status: 400, errorcode: 'illegal_request',
                 message: "Illegal request: PUT/POST #{request.path}: path does not match content"
    return
  end
end
