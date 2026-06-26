module Webui
  module Projects
    class LabelGlobalsController < WebuiController
      before_action :set_project

      def update
        authorize @project, policy_class: LabelGlobalPolicy

        if @project.update(labels_params)
          flash[:success] = 'Labels updated successfully!'
        else
          flash[:error] = @project.errors.full_messages.to_sentence
        end

        redirect_back_or_to root_path
      end

      private

      def labels_params
        params.require(:label_globals).permit(label_globals_attributes: [%i[id label_template_global_id _destroy]])
      end

      def set_project
        @project = Project.find_by_name(params[:project_name])
      end
    end
  end
end
