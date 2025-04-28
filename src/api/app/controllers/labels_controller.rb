class LabelsController < ApplicationController
  before_action :find_labelable
  before_action :xml_hash, :find_label_template, only: [:create]

  # GET /labels/projects/:project_name/packages/:package_name
  # GET /labels/requests/:request_number
  def index
    @labels = @labelable.labels
  end

  # POST /labels/projects/:project_name/packages/:package_name
  # POST /labels/requests/:request_number
  def create
    authorize @labelable, :update_labels?

    label = Label.new(label_template: @label_template, labelable: @labelable)
    if label.save
      render_ok
    else
      render_error(status: 400, message: label.errors.full_messages.to_sentence)
    end
  end

  # DELETE /labels/projects/:project_name/packages/:package_name/:id
  # DELETE /labels/requests/:request_number/:id
  def destroy
    authorize @labelable, :update_labels?
    label = @labelable.labels.find(params[:id])

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
    if @labelable.is_a?(BsRequest) && project_for_labels(@labelable).present?
      project = project_for_labels(@labelable)
      @label_template = project.label_templates.find(@parsed_xml[:label_template_id])
    elsif @labelable.is_a?(Package)
      @label_template = @labelable.project.label_templates.find(@parsed_xml[:label_template_id])
    else
      render_error(status: 400, message: 'Labeling requests with more than one target project are not supported')
    end
  end

  def project_for_labels(bs_request)
    target_project_ids = bs_request.bs_request_actions.pluck(:target_project_id).uniq
    return if target_project_ids.count > 1

    Project.find_by(id: target_project_ids.last)
  end
end
