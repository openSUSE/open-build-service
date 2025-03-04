class SourceAttributeController < SourceController
  include ValidationHelper
  before_action :set_request_data, only: [:update]
  before_action :find_attribute_container

  class RemoteProject < APIError
    setup 501, 'Attribute access to remote project is not yet supported'
  end

  class InvalidAttribute < APIError
  end

  class ChangeAttributeNoPermission < APIError
    setup 403
  end

  # GET
  # /source/:project/_attribute
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def show
    if params[:rev] || params[:meta] || params[:view] || @attribute_container.nil?
      # old or remote instance entry
      render xml: Backend::Api::Sources::Package.attributes(params[:project], params[:package], params)
      return
    end

    opts = { attrib_type: @at }.with_indifferent_access
    %i[binary with_default with_project].each { |p| opts[p] = params[p] }
    render xml: @attribute_container.render_attribute_axml(opts)
  end

  # DELETE
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def delete
    attrib = @attribute_container.find_attribute(@at.namespace, @at.name, @binary)

    # checks
    raise ActiveRecord::RecordNotFound, "Attribute #{params[:attribute]} does not exist" unless attrib
    raise ChangeAttributeNoPermission, "User #{User.possibly_nobody.login} has no permission to change attribute" unless User.possibly_nobody.can_create_attribute_in?(@attribute_container, @at)

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
    # This is necessary for checking the authorization and do not create the attribute
    # The attribute creation will happen in @attribute_container.store_attribute_xml
    @request_data.elements('attribute') do |attr|
      attrib_type = AttribType.find_by_namespace_and_name!(attr.value('namespace'), attr.value('name'))
      attrib = Attrib.new(attrib_type: attrib_type)

      attr.elements('value') do |value|
        attrib.values.new(value: value)
      end

      attrib.container = @attribute_container

      unless attrib.valid?
        render_error(message: attrib.errors.full_messages.join('\n'), status: 400, errorcode: attrib.errors.filter_map(&:type).first&.to_s)
        return false
      end

      authorize attrib, :create?
    end

    # exec
    @request_data.elements('attribute') do |attr|
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
      @attribute_container = Package.get_by_project_and_name(params[:project],
                                                             params[:package],
                                                             use_source: false)
    else
      # project
      raise RemoteProject if Project.remote_project?(params[:project])

      @attribute_container = Project.get_by_name(params[:project])
    end

    @at = attribute_type(params[:attribute])
  end
end
