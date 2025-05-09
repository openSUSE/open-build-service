class LabelsController < ApplicationController
  before_action :find_labelable
  before_action :xml_hash, only: [:create]

  # GET /labels/projects/:project_name/packages/:package_name
  # GET /labels/requests/:request_number
  def index
    @labels = authorize @labelable.labels
  end

  # POST /labels/projects/:project_name/packages/:package_name
  # POST /labels/requests/:request_number
  def create
    @label = authorize Label.new(labelable: @labelable)
    @label.label_template = find_label_template

    if @label.save
      render_ok
    else
      render_error(status: 400, errorcode: 'invalid_label', message: @label.errors.full_messages.to_sentence)
    end
  end

  # DELETE /labels/projects/:project_name/packages/:package_name/:id
  # DELETE /labels/requests/:request_number/:id
  def destroy
    label = authorize @labelable.labels.find_by(id: params[:id])

    unless label
      render_error(status: 404, message: "Unable to find label `#{params[:id]}`")
      return
    end

    if label.destroy
      render_ok
    else
      render_error(status: 400, message: "Unable to delete label `#{params[:id]}`")
    end
  end

  private

  def find_labelable
    if params[:request_number]
      @labelable = BsRequest.find_by(number: params[:request_number])
      @message = "Unable to find request '#{params[:request_number]}'"
    else
      @labelable = Package.get_by_project_and_name(params[:project_name], params[:package_name])
      @message = "Unable to find project '#{params[:project_name]}' and package '#{params[:package_name]}'"
    end

    render_error(status: 404, message: @message) && return unless @labelable
  end

  def xml_hash
    request_body = request.body.read
    @parsed_xml = Xmlhash.parse(request_body).with_indifferent_access if request_body.present?
    return if @parsed_xml.present?

    error_options = if request_body.present?
                      { status: 400, errorcode: 'invalid_xml_format', message: 'XML format is not valid' }
                    else
                      { status: 400, errorcode: 'invalid_request', message: 'Empty body' }
                    end
    render_error(error_options)
  end

  def find_label_template
    project = @label.project_for_labels
    return unless project

    project.label_templates.find(@parsed_xml[:label_template_id])
  end
end
