class SourceAttributeController < SourceController
  before_action :set_request_data, only: %i[update set]
  before_action :find_attribute_container
  before_action :validate_and_authorize_attributes, only: %i[update set]

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

  # POST
  # /source/:project/_attribute/:attribute
  # /source/:project/:package/_attribute/:attribute
  # /source/:project/:package/:binary/_attribute/:attribute
  #--------------------------------------------------------
  def update
    # exec
    any_change = false
    @request_data.elements('attribute') do |attr|
      any_change = @attribute_container.store_attribute_xml(attr, @binary).saved_changes?
    end
    # Single commit to backend
    @attribute_container.write_attributes if any_change
    render_ok
  end

  # PUT
  # /source/:project/_attribute
  # /source/:project/:package/_attribute
  #--------------------------------------------------------
  def set
    # exec
    @request_data.elements('attribute') do |attr|
      @attribute_container.store_attribute_xml(attr, @binary)
    end

    # cleanup not anymore used attributes
    attribs = if @attribute_container.is_a?(Project)
                Attrib.where(project: @attribute_container)
              else
                Attrib.where(package: @attribute_container)
              end
    attribs.each do |attrib|
      next if @request_data.elements('attribute').any? { |i| i['namespace'] == attrib.namespace && i['name'] == attrib.name }

      authorize attrib, :destroy?
      attrib.destroy!
    end

    # Single commit to backend
    @attribute_container.write_attributes
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

  def validate_and_authorize_attributes
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
  end
end
