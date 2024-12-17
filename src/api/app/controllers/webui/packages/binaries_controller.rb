module Webui
  module Packages
    class BinariesController < Webui::WebuiController
      include Webui::Packages::BinariesHelper

      # TODO: Keep in sync with Build::query in backend/build/Build.pm.
      #       Regexp.new('\.iso$') would be Build::Kiwi::queryiso which isn't implemented yet...
      QUERYABLE_BUILD_RESULTS = [Regexp.new('\.rpm$'),
                                 Regexp.new('\.deb$'),
                                 Regexp.new('\.pkg\.tar(?:\.gz|\.xz|\.zst)?$'),
                                 Regexp.new('\.arch$')].freeze

      before_action :set_project
      before_action :set_package
      before_action :set_multibuild_flavor
      before_action :set_repository
      before_action :set_architecture, only: %i[show dependency filelist]
      before_action :set_dependant_project, only: :dependency
      before_action :set_dependant_repository, only: :dependency
      before_action :set_filename, only: %i[show dependency filelist]

      prepend_before_action :lockout_spiders

      before_action :require_login, except: [:index]
      after_action :verify_authorized, only: [:destroy]

      def index
        results_from_backend = Buildresult.find_hashed(project: @project.name, package: @package_name, repository: @repository.name, view: %w[binarylist status])
        raise ActiveRecord::RecordNotFound, 'Not Found' if results_from_backend.empty?

        @buildresults = []
        results_from_backend.elements('result') do |result|
          build_results_set = { arch: result['arch'], statistics: false, repocode: result['state'], binaries: [] }

          result.get('binarylist').try(:elements, 'binary') do |binary|
            if binary['filename'] == '_statistics'
              build_results_set[:statistics] = true
            else
              build_results_set[:binaries] << { filename: binary['filename'],
                                                size: binary['size'],
                                                links: { details?: QUERYABLE_BUILD_RESULTS.any? { |regex| regex.match?(binary['filename']) },
                                                         download_url: download_url_for_binary(architecture_name: result['arch'], file_name: binary['filename']),
                                                         cloud_upload?: uploadable?(binary['filename'], result['arch']) } }
            end
          end
          @buildresults << build_results_set
        end
      rescue Backend::Error => e
        flash[:error] = e.message
        redirect_back_or_to({ controller: :package, action: :show, project: @project, package: @package })
      end

      def show
        @fileinfo = Backend::Api::BuildResults::Binaries.fileinfo_ext(@project.name, @package_name, @repository.name, @architecture.name, @filename)
        raise ActiveRecord::RecordNotFound, 'Not Found' unless @fileinfo

        respond_to do |format|
          format.html do
            @download_url = download_url_for_binary(architecture_name: @architecture.name, file_name: @filename)
          end
          format.any { redirect_to download_url_for_binary(architecture_name: @architecture.name, file_name: @filename) }
        end
      end

      def dependency
        @fileinfo = Backend::Api::BuildResults::Binaries.fileinfo_ext(@dependant_project_name, '_repository', @dependant_repository_name,
                                                                      @architecture, params[:dependant_name])
        return if @fileinfo # avoid displaying an error for non-existing packages

        redirect_back_or_to project_package_repository_binary_url(project_name: @project, package_name: @package,
                                                                  repository: @repository, arch: @architecture, filename: @filename)
      end

      def destroy
        authorize @package, :update?

        begin
          Backend::Api::Build::Project.wipe_binaries(@project.name, { package: @package_name,
                                                                      repository: params[:repository_name],
                                                                      arch: params[:arch] }.compact)
          flash[:success] = "Triggered wipe binaries for #{elide(@project.name)}/#{elide(@package_name)} successfully."
        rescue Backend::Error, Timeout::Error, Project::WritePermissionError => e
          flash[:error] = "Error while triggering wipe binaries for #{elide(@project.name)}/#{elide(@package_name)}: #{e.message}."
        end

        redirect_to project_package_repository_binaries_path(project_name: @project, package_name: @package_name, repository_name: @repository)
      end

      def filelist
        data = Backend::Api::BuildResults::Binaries.fileinfo_ext(@project.name, @package_name, @repository.name, @architecture.name, @filename, withfilelist: 1)
        filelist = data.elements('filelist')
        render json: { data: filelist.map { |f| { name: f } } }
      end

      private

      def set_dependant_project
        @dependant_project_name = params[:dependant_project]
        @dependant_project = Project.find_by_name(@dependant_project_name) || Project.find_remote_project(@dependant_project_name).try(:first)
        return @dependant_project if @dependant_project

        flash[:error] = "Project '#{elide(@dependant_project_name)}' is invalid."
        redirect_back_or_to root_path
      end

      def set_dependant_repository
        @dependant_repository_name = params[:dependant_repository]
        # FIXME: It can't check repositories of remote projects
        @dependant_repository = @dependant_project.repositories.find_by(name: @dependant_repository_name) if @dependant_project.remoteurl.blank?
        return @dependant_repository if @dependant_repository

        flash[:error] = "Repository '#{@dependant_repository_name}' is invalid."
        redirect_back_or_to project_show_path(project: @project.name)
      end

      def set_filename
        # Ensure it really is just a file name, no '/..', etc.
        @filename = File.basename(params[:binary_filename] || params[:filename])
      end

      def set_multibuild_flavor
        @multibuild_flavor = @package_name.gsub(/.*:/, '') if @package_name.present? && @package_name.include?(':')
      end

      # Get an URL to a binary produced by the build.
      # In the published repo for everyone, in the backend directly only for logged in users.
      def download_url_for_binary(architecture_name:, file_name:)
        if publishing_enabled(architecture_name: architecture_name)
          published_url = Backend::Api::BuildResults::Binaries.download_url_for_file(@project.name, @repository.name, @package_name, architecture_name, file_name)
          return published_url if published_url
        end

        "/build/#{@project.name}/#{@repository.name}/#{architecture_name}/#{@package_name}/#{file_name}" if User.session
      end

      def publishing_enabled(architecture_name:)
        if @project == @package.project
          @package.enabled_for?('publish', @repository.name, architecture_name)
        else
          # We are looking at a package coming through a project link
          # Let's see if we rebuild linked packages.
          # NOTE: linkedbuild=localdep||alldirect would be too much hassle to figure out...
          return false if @repository.linkedbuild != 'all'

          # If we are rebuilding packages, let's ask @project if it publishes.
          @project.enabled_for?('publish', @repository.name, architecture_name)
        end
      end
    end
  end
end
