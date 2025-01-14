module Webui
  class LabelTemplatesController < WebuiController
    def index
      authorize LabelTemplateGlobal.new

      @label_templates = LabelTemplateGlobal.all
    end

    def new
      @label_template = authorize LabelTemplateGlobal.new
      @label_template.set_random_color
    end

    def edit
      @label_template = authorize LabelTemplateGlobal.find(params[:id])
    end

    def create
      @label_template = authorize LabelTemplateGlobal.new(label_template_params)

      if @label_template.save
        redirect_to label_templates_path
        flash[:success] = 'Label Template created successfully'
      else
        render :new
        flash[:error] = 'Failed to create the Label Template'
      end
    end

    def update
      @label_template = authorize LabelTemplateGlobal.find(params[:id])

      if @label_template.update(label_template_params)
        redirect_to label_templates_path
        flash[:success] = 'Label Template updated successfully'
      else
        render :edit
        flash[:error] = 'Failed to update the Label Template'
      end
    end

    def destroy
      @label_template = authorize LabelTemplateGlobal.find(params[:id])

      if @label_template.destroy
        flash[:success] = 'Label Template deleted successfully'
      else
        flash[:error] = 'Failed to delete the Label Template'
      end
      redirect_to label_templates_path
    end

    private

    def label_template_params
      params.require(:label_template_global).permit(:name, :color)
    end
  end
end
