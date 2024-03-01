module Webui
  module Projects
    class BsRequestLabelsController < WebuiController
      before_action :find_label, only: [:destroy, :update]
      before_action :set_project

      def index
        @labels = BsRequestLabel.all
      end

      def new
        @label = BsRequestLabel.new

        @labels = BsRequestLabel.all
      end

      def create
        authorize @project, :create?
        @label = BsRequestLabel.new(label_params)
        respond_to do |format|
          if @label.save
            format.js { render 'create_success' }
          else
            format.js { render 'create_failure'}
          end
        end
      end

      def destroy
        authorize @project, :destroy?

        if @label.destroy
          flash[:success] = "Label was successfully deleted."
        else
          flash[:error] = "Failed to delete label"
        end
        redirect_to new_project_label_path
      end

      def update
        respond_to do |format|
          if @label.update(label_params)
            format.js { render 'update_success' }
          else
            format.js { render 'update_failure'}
          end
        end
      end

      private

      def find_label
        @label = BsRequestLabel.find(params[:id])
      end

      def label_params
        params.require(:label).permit(:name, :description)
      end
    end
  end
end