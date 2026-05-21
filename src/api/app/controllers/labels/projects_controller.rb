class Labels::ProjectsController < ApplicationController
  before_action :set_project
  before_action :authorize_with_label_global_policy
  before_action :set_label, only: %i[destroy]
  before_action :xml_hash, :set_label_template, only: [:create]

  after_action :verify_authorized # raise an exception if authorize has not yet been called.

  # GET /labels/projects/:project_name
  def index
    @labels = @project.label_globals

    render 'labels/index', formats: [:xml]
  end

  # POST /labels/projects/:project_name
  def create
    @label = @project.label_globals.new(label_template_global: @label_template)

    if @label.save
      render_ok
    else
      render_error message: @label.errors.full_messages.to_sentence,
                   status: 400, errorcode: 'invalid_label'
    end
  end

  # DELETE /labels/projects/:project_name/1
  def destroy
    @label = @project.label_globals.find(params[:id])

    @label.destroy

    render_ok
  end

  private

  def set_project
    @project = Project.get_by_name(params[:project_name])
  end

  def authorize_with_label_global_policy
    authorize @project, policy_class: LabelGlobalPolicy
  end

  def set_label
    @label = LabelGlobal.find(params[:id])
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

  def set_label_template
    @label_template = LabelTemplateGlobal.find(@parsed_xml[:label_template_id])
  end
end
