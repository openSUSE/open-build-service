class AttributeNamespaceController < ApplicationController
  include ValidationHelper

  validate_action index: { method: :get, response: :directory }
  validate_action show: { method: :get, response: :attribute_namespace_meta }
  validate_action delete: { method: :delete, response: :status }
  validate_action update: { method: :put, request: :attribute_namespace_meta, response: :status }
  validate_action update: { method: :post, request: :attribute_namespace_meta, response: :status }
  before_action :require_namespace, only: [:show, :delete, :update]
  before_action :require_admin, only: [:update, :delete]

  def index
    if params[:namespace]
      an = AttribNamespace.find_by_name!(params[:namespace])
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

  def show
    if (@an = AttribNamespace.find_by_name!(@namespace))
      render template: 'attribute_namespace/show'
    else
      render_error message: "Unknown attribute namespace '#{@namespace}'",
        status: 404, errorcode: 'unknown_attribute_namespace'
    end
  end

  def delete
    AttribNamespace.where(name: @namespace).destroy_all
    render_ok
  end

  # /attribute/:namespace/_meta
  def update
    xml_element = Xmlhash.parse(request.raw_post)

    unless xml_element['name'] == @namespace
      render_error status: 400, errorcode: 'illegal_request',
        message: "Illegal request: PUT/POST #{request.path}: path does not match content"
      return
    end

    db = AttribNamespace.find_by_name(@namespace)
    if db
      db.update_from_xml(xml_element)
    else
      AttribNamespace.create(name: @namespace).update_from_xml(xml_element)
    end

    render_ok
  end

  private

  def require_namespace
    @namespace = params[:namespace]
  end
end
