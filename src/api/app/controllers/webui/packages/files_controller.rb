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

      def save_files
        authorize @package, :update?
        filenames = params[:filenames]
        filelist = []

        errors = []

        xml = ::Builder::XmlMarkup.new

        # Iterate over existing files first to keep them in file list
        @package.dir_hash.elements('entry') { |e| xml.entry('name' => e['name'], 'md5' => e['md5'], 'hash' => e['hash']) }
        begin
          # Add new services to _service
          if params[:file_urls].present?
            services = @package.services

            Hash[*params[:file_urls]].try(:each) do |name, url|
              services.addDownloadURL(url, name)
            end

            if services.save
              filelist << '_service'
            else
              errors << 'Failed to add file from URL'
            end
          end
          # Assign names to the uploaded files
          params[:files].try(:each) do |file|
            filenames[file.original_filename] ||= file.original_filename
            filelist << filenames[file.original_filename]
            @package.save_file(rev: 'repository', file: file, filename: filenames[file.original_filename])
            content = File.open(file.path).read if file.is_a?(ActionDispatch::Http::UploadedFile)
            xml.entry('name' => filenames[file.original_filename], 'md5' => Digest::MD5.hexdigest(content), 'hash' => 'sha256:' + Digest::SHA256.hexdigest(content))
          end
          # Create new files from the namelist
          params[:files_new].try(:each) do |new|
            filelist << new
            @package.save_file(rev: 'repository', filename: new)
            xml.entry('name' => new, 'md5' => Digest::MD5.hexdigest(''), 'hash' => 'sha256:' + Digest::SHA256.hexdigest(''))
          end

          if filelist.blank?
            errors << 'No file uploaded, empty file specified or URI given'
          else
            Backend::Api::Sources::Package.write_filelist(@package.project.name, @package.name, "<directory>#{xml.target!}</directory>", user: User.session!.login, comment: params[:comment])
            return if ['_project', '_pattern'].include?(@package.name)

            @package.sources_changed(wait_for_update: ['_aggregate', '_constraints', '_link', '_service', '_patchinfo', '_channel'].any? { |i| filelist.include?(i) })
          end
        rescue APIError => e
          errors << e.message
        rescue Backend::Error => e
          errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
        rescue StandardError => e
          errors << e.message
        end

        if errors.empty?
          message = "'#{filelist}' have been successfully saved."
          redirect_to({ action: :show, project: @project, package: @package }, success: message)
        else
          message = "Error while creating '#{filelist}': #{errors.compact.join("\n")}."
          redirect_back(fallback_location: root_path, error: message)
        end
      end
    end
  end
end
