module Webui
  module Projects
    class LabelTemplatesController < WebuiController
      before_action :set_project

      def index
        authorize LabelTemplate.new(project: @project), :index?

        @label_templates = @project.label_templates
      end

      def new
        @label_template = authorize @project.label_templates.new
      end

      def edit
        @label_template = authorize @project.label_templates.find(params[:id])
      end

      def create
        @label_template = authorize @project.label_templates.new(label_template_params)

        if @label_template.save
          redirect_to project_label_templates_path(@project)
        else
          render :new
        end
      end

      def update
        @label_template = authorize @project.label_templates.find(params[:id])

        if @label_template.update(label_template_params)
          redirect_to project_label_templates_path(@project)
        else
          render :edit
        end
      end

      private

      def label_template_params
        params.require(:label_template).permit(:name, :color)
      end
    end
  end
end
