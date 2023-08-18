module Webui
  module Packages
    class BinariesController < Packages::MainController
      include Webui::Packages::BinariesHelper

      # TODO: Keep in sync with Build::query in backend/build/Build.pm.
      #       Regexp.new('\.iso$') would be Build::Kiwi::queryiso which isn't implemented yet...
      QUERYABLE_BUILD_RESULTS = [Regexp.new('\.rpm$'),
                                 Regexp.new('\.deb$'),
                                 Regexp.new('\.pkg\.tar(?:\.gz|\.xz|\.zst)?$'),
                                 Regexp.new('\.arch$')].freeze

      before_action :set_project
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture, only: [:show]

      prepend_before_action :lockout_spiders

      before_action :require_login, except: [:index]

      def index
        results_from_backend = Buildresult.find_hashed(project: @project.name, package: @package.name, repository: @repository.name, view: ['binarylist', 'status'])
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
        redirect_back(fallback_location: { controller: :package, action: :show, project: @project, package: @package })
      end

      def show
        # Ensure it really is just a file name, no '/..', etc.
        @filename = File.basename(params[:filename])

        @fileinfo = Backend::Api::BuildResults::Binaries.fileinfo_ext(@project.name, @package.name, @repository.name, @architecture.name, @filename)
        raise ActiveRecord::RecordNotFound, 'Not Found' unless @fileinfo

        respond_to do |format|
          format.html do
            @download_url = download_url_for_binary(architecture_name: @architecture.name, file_name: @filename)
          end
          format.any { redirect_to download_url_for_binary(architecture_name: @architecture.name, file_name: @filename) }
        end
      end

      # Get an URL to a binary produced by the build.
      # In the published repo for everyone, in the backend directly only for logged in users.
      def download_url_for_binary(architecture_name:, file_name:)
        if publishing_enabled(architecture_name: architecture_name)
          published_url = Backend::Api::BuildResults::Binaries.download_url_for_file(@project.name, @repository.name, @package.name, architecture_name, file_name)
          return published_url if published_url
        end

        "/build/#{@project.name}/#{@repository.name}/#{architecture_name}/#{@package.name}/#{file_name}" if User.session
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
