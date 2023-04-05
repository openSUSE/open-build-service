module Webui
  module Packages
    class BinariesController < Packages::MainController
      include Webui::Packages::BinariesHelper

      before_action :set_project
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture

      prepend_before_action :lockout_spiders

      before_action :require_login

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
