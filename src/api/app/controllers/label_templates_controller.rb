class LabelTemplatesController < ApplicationController
  before_action :set_label_template, only: %i[update destroy]

  after_action :verify_authorized # raise an exception if authorize has not yet been called.

  # GET /label_templates
  def index
    authorize LabelTemplateGlobal
    @label_templates = LabelTemplateGlobal.all

    render 'label_templates/index', formats: [:xml]
  end

  # POST /label_templates
  def create
    @label_template = LabelTemplateGlobal.new(label_template_params)
    authorize @label_template

    if @label_template.save
      render_ok
    else
      render_error message: @label_template.errors.full_messages.to_sentence,
                   status: 400, errorcode: 'invalid_label_template'
    end
  end

  # PATCH/PUT /label_templates/1
  def update
    authorize @label_template

    if @label_template.update(label_template_params)
      render_ok
    else
      render_error message: @label_template.errors.full_messages.to_sentence,
                   status: 400, errorcode: 'invalid_label_template'
    end
  end

  # DELETE /label_templates/1
  def destroy
    authorize @label_template
    @label_template.destroy

    render_ok
  end

  private

  def set_label_template
    @label_template = LabelTemplateGlobal.find(params[:id])
  end

  def label_template_params
    xml = Nokogiri::XML(request.raw_post, &:strict)
    color = xml.xpath('//label_template/color').text
    name = xml.xpath('//label_template/name').text
    { color: color, name: name }
  end
end
