class SourceAttributeController < ApplicationController
  include ValidationHelper

  before_action :require_valid_project_name
  before_action :find_attribute_container

  class RemoteProject < APIException
    setup 400, 'Attribute access to remote project is not yet supported'
  end

  class InvalidAttribute < APIException
  end

  class ChangeAttributeNoPermission < APIException
    setup 403
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

    if @at
      params[:namespace] = @at.namespace
      params[:name] = @at.name
    end
    render xml: @attribute_container.render_attribute_axml(params)
  end

  # DELETE
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def delete
    attrib = @attribute_container.find_attribute(@at.namespace, @at.name, @binary)

    # checks
    unless attrib
      raise ActiveRecord::RecordNotFound, "Attribute #{params[:attribute]} does not exist"
    end
    unless User.current.can_create_attribute_in? @attribute_container, @at
      raise ChangeAttributeNoPermission, "User #{user.login} has no permission to change attribute"
    end

    # exec
    attrib.destroy
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

  def attribute_type(name)
    return if name.blank?
    # if an attribute param is given, it needs to exist
    AttribType.find_by_name!(name)
  end

  def find_attribute_container
    # init and validation
    #--------------------
    @binary = params[:binary]
    # valid post commands
    if params[:package] && params[:package] != '_project'
      @attribute_container = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
    else
      # project
      raise RemoteProject if Project.is_remote_project?(params[:project])
      @attribute_container = Project.get_by_name(params[:project])
    end

    @at = attribute_type(params[:attribute])
  end
end
