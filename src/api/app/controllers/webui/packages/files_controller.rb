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

        file = params[:file]
        file_url = params[:file_url]
        filename = params[:filename]

        errors = []

        begin
          if file.present?
            # We are getting an uploaded file
            filename = file.original_filename if filename.blank?
            @package.save_file(file: file, filename: filename, comment: params[:comment])
          elsif file_url.present?
            # we have a remote file URI, so we have to download and save it
            services = @package.services

            # detects automatically git://, src.rpm formats
            services.add_download_url(file_url, filename)

            errors << "Failed to add file from URL '#{file_url}'" unless services.save
          elsif filename.present? # No file is provided so we just create an empty new file (touch)
            @package.save_file(filename: filename)
          else
            errors << 'No file or URI given'
          end
        rescue Backend::Error => e
          errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
        rescue APIError, StandardError => e
          errors << e.message
        end

        if errors.empty?
          message = "The file '#{filename}' has been successfully saved."
          # We have to check if it's an AJAX request or not
          if request.xhr?
            flash.now[:success] = message
          else
            redirect_to(package_show_path(project: @project, package: @package), success: message)
            return
          end
        else
          message = "Error while creating '#{filename}' file: #{errors.compact.join("\n")}."
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
  end
end
