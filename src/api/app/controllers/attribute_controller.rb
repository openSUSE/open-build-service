class AttributeController < ApplicationController
  include ValidationHelper

  validate_action show: { method: :get, response: :attrib_type }
  validate_action delete: { method: :delete, response: :status }
  validate_action update: { method: :put, request: :attrib_type, response: :status }
  validate_action update: { method: :post, request: :attrib_type, response: :status }
  before_action :load_attribute, only: [:show, :update, :delete]

  # GET /attribute/:namespace/:name/_meta
  def show
    if @at
      render template: 'attribute/show'
    else
      render_error message: "Unknown attribute '#{@namespace}':'#{@name}'",
                   status: 404, errorcode: 'unknown_attribute'
    end
  end

  # DELETE /attribute/:namespace/:name/_meta
  # DELETE /attribute/:namespace/:name
  def delete
    if @at
      authorize @at, :destroy?
      @at.destroy
    end

    render_ok
  end

  # POST/PUT /attribute/:namespace/:name/_meta
  def update
    return unless (xml_element = validate_xml)

    if @at
      authorize @at, :update?
      @at.update_from_xml(xml_element)
    else
      create(xml_element)
    end

    render_ok
  end

  private

  def load_attribute
    @namespace = params[:namespace]
    @ans = AttribNamespace.find_by_name!(@namespace)
    if params[:name].nil?
      raise MissingParameterError, "parameter 'name' is missing"
    end
    @name = params[:name]
    # find_by_name is something else (of course)
    @at = @ans.attrib_types.where(name: @name).first
  end

  def create(xml_element)
    entry = AttribType.new(name: @name, attrib_namespace: @ans)
    authorize entry, :create?

    entry.update_from_xml(xml_element)
  end

  def validate_xml
    xml_element = Xmlhash.parse(request.raw_post)

    return xml_element if xml_element && xml_element['name'] == @name && xml_element['namespace'] == @namespace
    render_error status: 400, errorcode: 'illegal_request',
                 message: "Illegal request: PUT/POST #{request.path}: path does not match content"
    return
  end
end
