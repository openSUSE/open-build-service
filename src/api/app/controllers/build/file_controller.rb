# frozen_string_literal: true
module Build
  class FileController < ApplicationController
    before_action :check_user_has_permission
    before_action :require_parameters

    # GET /build/:project/:repository/:arch/:package/:filename
    def show
      if regexp
        process_regexp
      else
        pass_to_backend path
      end
    end

    # PUT /build/:project/:repository/:arch/:package/:filename
    def update
      if regexp
        process_regexp
      else
        unless User.current.is_admin?
          # this route can be used publish binaries without history changes in sources
          render_error status: 403, errorcode: 'upload_binary_no_permission',
            message: 'No permission to upload binaries.'
          return
        end

        pass_to_backend path
      end
    end

    # DELETE /build/:project/:repository/:arch/:package/:filename
    def destroy
      unless permissions.project_change? params[:project]
        render_error status: 403, errorcode: 'delete_binary_no_permission',
          message: "No permission to delete binaries from project #{params[:project]}"
        return
      end

      if params[:package] == '_repository'
        pass_to_backend
      else
        render_error status: 400, errorcode: 'invalid_operation',
          message: 'Delete operation of build results is not allowed'
      end

      return
    end

    private

    def require_parameters
      required_parameters :project, :repository, :arch, :package, :filename
    end

    def project
      @project ||=
        if params[:package] == '_repository'
          Project.get_by_name params[:project]
        else
          package = Package.get_by_project_and_name(
            params[:project], params[:package], use_source: false, follow_multibuild: true
          )
          package.project if package.present?
        end
    end

    def check_user_has_permission
      user_has_permission =
        !(
          project.class == Project &&
          project.disabled_for?('binarydownload', params[:repository], params[:arch]) &&
          !User.current.can_download_binaries?(project)
        )

      return if user_has_permission

      render_error status: 403, errorcode: 'download_binary_no_permission',
        message: "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
      return
    end

    def path
      @path ||= request.path_info + '?' + request.query_string
    end

    def regexp
      # if there is a query, we can't assume it's a simple download, so better leave out the logic (e.g. view=fileinfo)
      return if request.query_string
      # check if binary exists and for size
      regexp = /name=["']#{Regexp.quote params[:filename]}["'].*size=["']([^"']*)["']/
      @regexp ||= Backend::Api::BuildResults::Binaries.files(params[:project], params[:repository], params[:arch], params[:package]).match(regexp)
    end

    def process_regexp
      fsize = regexp[1]
      logger.info "streaming #{path}"

      c_type =
        case params[:filename].split(/\./)[-1]
        when 'rpm' then 'application/x-rpm'
        when 'deb' then 'application/x-deb'
        when 'iso' then 'application/x-cd-image'
        else 'application/octet-stream'
        end

      headers.update(
        'Content-Disposition' => %(attachment; filename="#{params[:filename]}"),
        'Content-Type' => c_type,
        'Transfer-Encoding' => 'binary',
        'Content-Length' => fsize
      )

      render status: 200, text: proc { |_, output|
        backend_request = Net::HTTP::Get.new(path)
        Net::HTTP.start(CONFIG['source_host'], CONFIG['source_port']) do |http|
          http.request(backend_request) do |response|
            response.read_body do |chunk|
              output.write(chunk)
            end
          end
        end
      }
    end
  end
end
