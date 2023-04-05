module Webui::Packages::BinariesHelper
  include Webui::WebuiHelper

  def uploadable?(filename, architecture)
    ::Cloud::UploadJob.new(filename: filename, arch: architecture).uploadable?
  end

  # Get an URL to a binary produced by the build.
  # In the published repo for everyone, in the backend directly only for logged in users.
  def download_url_for_binary(project, repository, package, architecture_name, file_name)
    if publishing_enabled(project, repository, package, architecture_name)
      published_url = Backend::Api::BuildResults::Binaries.download_url_for_file(project.name, repository.name, package.name, architecture_name, file_name)
      return published_url if published_url
    end

    return "/build/#{project.name}/#{repository.name}/#{architecture_name}/#{package.name}/#{file_name}" if User.session
  end

  private

  def publishing_enabled(project, repository, package, architecture_name)
    if project == package.project
      package.enabled_for?('publish', repository.name, architecture_name)
    else
      # We are looking at a package coming through a project link
      # Let's see if we rebuild linked packages.
      # NOTE: linkedbuild=localdep||alldirect would be too much hassle to figure out...
      return false if repository.linkedbuild != 'all'

      # If we are rebuilding packages, let's ask project if it publishes.
      project.enabled_for?('publish', repository.name, architecture_name)
    end
  end
end
