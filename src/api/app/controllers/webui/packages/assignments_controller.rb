module Webui
  module Packages
    class AssignmentsController < Webui::WebuiController
      before_action :require_login
      before_action :set_package
      before_action :set_assignee, except: :destroy

      def create
        assignment = authorize Assignment.new(assigner: User.session, assignee: @assignee, package: @package)

        unless assignment.save
          flash[:error] = "Could not assign the user: #{assignment.errors.full_messages.to_sentence}"
        end
        redirect_to package_show_path(@package.project, @package)
      end

      def destroy
        assignment = authorize Assignment.find(params['id'])
        if assignment
          assignment.destroy
        end
        redirect_to package_show_path(@package.project, @package)
      end

      private

      def set_package
        @package = Package.find_by_project_and_name(params['project_name'], params['package_name'])
      end

      def set_assignee
        @assignee = User.find_by(login: params[:assignee])
      end
    end
  end
end
