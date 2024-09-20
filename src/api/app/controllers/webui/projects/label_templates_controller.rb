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
        @label_template.set_random_color
      end

      def edit
        @label_template = authorize @project.label_templates.find(params[:id])
      end

      def create
        @label_template = authorize @project.label_templates.new(label_template_params)

        if @label_template.save
          redirect_to project_label_templates_path(@project)
          flash[:success] = 'Label template created successfully'
        else
          render :new
          flash[:error] = 'Failed to create the label template'
        end
      end

      def update
        @label_template = authorize @project.label_templates.find(params[:id])

        if @label_template.update(label_template_params)
          redirect_to project_label_templates_path(@project)
          flash[:success] = 'Label template updated successfully'
        else
          render :edit
          flash[:error] = 'Failed to update the label template'
        end
      end

      def destroy
        @label_template = authorize @project.label_templates.find(params[:id])

        if @label_template.destroy
          redirect_to project_label_templates_path(@project)
          flash[:success] = 'Label template deleted successfully'
        else
          render :edit
          flash[:error] = 'Failed to delete the label template'
        end
      end

      def copy
        authorize @project.label_templates.new, :new?
      end

      def clone
        authorize @project.label_templates.new, :new?
        @source_project = Project.find_by(name: params[:source_project])

        if @project.label_templates << (@source_project&.label_templates&.map(&:dup) || [])
          redirect_to project_label_templates_path(@project)
          flash[:success] = 'Label templates copied successfully'
        else
          render :copy
          flash[:error] = 'Failed to copy the label templates'
        end
      end

      def preview
        authorize @project.label_templates.new, :new?
        render(partial: 'preview', locals: { project: Project.find_by(name: params[:project]) })
      end

      private

      def label_template_params
        params.require(:label_template).permit(:name, :color)
      end
    end
  end
end
