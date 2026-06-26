class LabelTemplates::ProjectsController < ApplicationController
  before_action :set_project
  before_action :set_label_template, only: %i[update destroy]

  after_action :verify_authorized # raise an exception if authorize has not yet been called.

  # GET /label_templates
  def index
    authorize LabelTemplate.new(project: @project)
    @label_templates = @project.label_templates

    render 'label_templates/index', formats: [:xml]
  end

  # POST /label_templates/projects/:project_name
  def create
    @label_template = authorize @project.label_templates.new(label_template_params)

    if @label_template.save
      render_ok
    else
      render_error message: @label_template.errors.full_messages.to_sentence,
                   status: 400, errorcode: 'invalid_label_template'
    end
  end

  # PATCH/PUT /label_templates/projects/:project_name/1
  def update
    authorize @label_template

    if @label_template.update(label_template_params)
      render_ok
    else
      render_error message: @label_template.errors.full_messages.to_sentence,
                   status: 400, errorcode: 'invalid_label_template'
    end
  end

  # DELETE /label_templates/projects/:project_name/1
  def destroy
    authorize @label_template
    @label_template.destroy

    render_ok
  end

  private

  def set_project
    @project = Project.get_by_name(params[:project_name])
  end

  def set_label_template
    @label_template = LabelTemplate.find(params[:id])
  end

  def label_template_params
    xml = Nokogiri::XML(request.raw_post, &:strict)
    color = xml.xpath('//label_template/color').text
    name = xml.xpath('//label_template/name').text
    { color: color, name: name }
  end
end
