module Webui
  module Packages
    class FilesController < Packages::MainController
      before_action :set_project
      before_action :set_package
      after_action :verify_authorized

      def new
        authorize @package, :update?
      end

      def create
        authorize @package, :update?

        binding.pry
        
        upload_service = FileService::Uploader.new(@package, params[:files],
                                  params[:files_new], params[:file_urls],
                                  params[:comment])
        upload_service.call
        errors = upload_service.errors
        added_files = upload_service.added_files.join(', ')

        if errors.blank?
          message = "'#{added_files}' has been successfully saved."
          # We have to check if it's an AJAX request or not
          if request.xhr?
            flash.now[:success] = message
          else
            redirect_to(package_show_path(project: @project, package: @package), success: message)
            return
          end
        else
          message = "Error while adding '#{added_files}': #{errors.compact.join("\n")}."
          # We have to check if it's an AJAX request or not
          if request.xhr?
            flash.now[:error] = message
            status = 400
          else
            redirect_back(fallback_location: root_path, error: message)
            return
          end
        end

        status ||= 200
        render layout: false, status: status, partial: 'layouts/webui/flash', object: flash
      end
    end

    private

    def handle_xhr_upload
      return unless request.xhr?


    end
  end
end
