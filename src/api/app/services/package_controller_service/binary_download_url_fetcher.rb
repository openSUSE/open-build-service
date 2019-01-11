module PackageControllerService
  class BinaryDownloadUrlFetcher
    include Webui::PackageHelper

    attr_reader :download_url

    def initialize(user, project, params)
      @user = user
      @project = project
      @params = params
    end

    def repository
      Repository.find_by_project_and_name(@project.to_s, @params[:repository].to_s)
    end

    def architecture
      Architecture.find_by_name(@params[:arch]).name
    end

    def filename
      @filename = File.basename(@params[:filename]) # Ensure it really is just a file name, no '/..', etc.
    end

    def call
      @download_url = download_url_for_file_in_repo(@user, @project, @params[:package], repository, architecture, filename)
      self
    end

    def self.file_available?(url, max_redirects = 5)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 15
      http.read_timeout = 15
      response = http.head uri.path
      if response.code.to_i == 302 && response['location'] && max_redirects > 0
        return file_available?(response['location'], (max_redirects - 1))
      end
      return response.code.to_i == 200
    rescue Object
      return false
    end
  end
end
