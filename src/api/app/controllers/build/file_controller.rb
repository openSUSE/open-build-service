module Build
  class FileController < ApplicationController
    before_action :check_user_has_permission
    before_action :require_parameters

    # GET /build/:project/:repository/:arch/:package/:filename
    def show
      if %w[_buildenv _statistics].include?(params[:filename])
        render xml: Backend::Api::BuildResults::Binaries.file(params[:project], params[:repository], params[:arch], params[:package], params[:filename])
      else
        pass_to_backend(path)
      end
    end

    # PUT /build/:project/:repository/:arch/:package/:filename
    def update
      unless User.admin_session?
        # this route can be used publish binaries without history changes in sources
        render_error status: 403, errorcode: 'upload_binary_no_permission',
                     message: 'No permission to upload binaries.'
        return
      end

      pass_to_backend(path)
    end

    # DELETE /build/:project/:repository/:arch/:package/:filename
    def destroy
      unless permissions.project_change?(params[:project])
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

      nil
    end

    private

    def require_parameters
      required_parameters :project, :repository, :arch, :package, :filename
    end

    def project
      @project ||=
        if params[:package] == '_repository'
          Project.get_by_name(params[:project])
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
          project.instance_of?(Project) &&
          project.disabled_for?('binarydownload', params[:repository], params[:arch]) &&
          !User.possibly_nobody.can_download_binaries?(project)
        )

      return if user_has_permission

      render_error status: 403, errorcode: 'download_binary_no_permission',
                   message: "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
      nil
    end

    def path
      @path ||= "#{request.path_info}?#{request.query_string}"
    end
  end
end
