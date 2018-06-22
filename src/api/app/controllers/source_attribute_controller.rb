class SourceAttributeController < ApplicationController
  include ValidationHelper

  before_action :require_valid_project_name
  before_action :find_attribute_container

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
  def show
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
  def delete
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

  # POST/PUT
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def update
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
end
