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

        upload_service = FileService::Uploader.new(@package, params[:files],
                                  params[:files_new], params[:file_urls],
                                  params[:comment])
        upload_service.call
        errors = upload_service.errors
        added_files = upload_service.added_files.join(', ')

        if errors.blank?
          redirect_to(package_show_path(project: @project, package: @package),
                                        success: "'#{added_files}' has been successfully saved.")
        else
          redirect_back(fallback_location: root_path, error: "Error while adding '#{added_files}':
                                                              #{errors.compact.join("\n")}.")
        end
      end

      def update
        return unless request.xhr?

        authorize @package, :update?

        errors = []

        begin
          @package.save_file(file: params[:file], filename: params[:filename],
                             comment: params[:comment])
        rescue APIError => e
          errors << e.message
        rescue Backend::Error => e
          errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
        rescue StandardError => e
          errors << e.message
        end

        if errors.blank?
          flash.now[:success] = "'#{params[:filename]}' has been successfully saved."
        else
          flash.now[:error] = "Error while adding '#{params[:filename]}': #{errors.compact.join("\n")}."
          status = 400
        end

        status ||= 200
        render layout: false, status: status, partial: 'layouts/webui/flash', object: flash
      end
    end
  end
end
