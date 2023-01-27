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

        files = params[:files] || []
        filename = params[:filename]
        files << ActionDispatch::Http::UploadedFile.new(tempfile: Tempfile.new(''), filename: filename) if filename.present?
        file_url = params[:file_url]

        errors = []

        if file_url.present?
          # we have a remote file URI, so we have to download and save it
          services = @package.services

          # detects automatically git://, src.rpm formats
          services.add_download_url(file_url, filename)
          added_files = filename || '_service'

          errors << "Failed to add file from URL '#{file_url}'" unless services.save
        elsif files.present?
          # we get files to upload to the backend
          upload_service = FileService::Uploader.new(@package, files, params[:comment])
          upload_service.call
          errors << upload_service.errors
          added_files = upload_service.added_files
        else
          errors << 'No file or URI given'
        end

        if errors.compact_blank.empty?
          redirect_to(package_show_path(project: @project, package: @package),
                      success: "#{added_files} have been successfully saved.")
        else
          redirect_back(fallback_location: root_path,
                        error: "Error while creating #{added_files} files: #{errors.compact_blank.join("\n")}.")
        end
      end

      def update
        return unless request.xhr?

        authorize @package, :update?

        errors = []

        begin
          @package.save_file(file: params[:file], filename: params[:filename],
                             comment: params[:comment])
        rescue APIError, StandardError => e
          errors << e.message
        rescue Backend::Error => e
          errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
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
