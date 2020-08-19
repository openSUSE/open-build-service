module PackageControllerService
  class URLGenerator
    def initialize(params = {})
      @project = params[:project]
      @repository = params[:repository]
      @arch = params[:arch]
      @filename = params[:filename]
      @user = params[:user]
      @package = params[:package]
    end

    def logger
      Rails.logger
    end

    def rpm_url
      get_frontend_url_for(controller: 'build') +
        "/#{@project}/#{@repository}/#{@arch}/#{@package}/#{@filename}"
    end

    def download_url_for_file_in_repo
      download_url = @repository.download_url_for_file(@package, @arch, @filename)
      # return mirror if available
      return download_url if download_url && file_available?(download_url)

      # only use API for logged in users if the mirror is not available - return nil otherwise
      rpm_url unless @user.is_nobody?
    end

    def file_available?(url, max_redirects = 5)
      logger.debug "Checking url: #{url}"
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 15
      http.read_timeout = 15
      response = http.head uri.path
      return file_available?(response['location'], (max_redirects - 1)) if response.code.to_i == 302 && response['location'] && max_redirects.positive?

      return response.code.to_i == 200
    rescue Object => e
      logger.error "Error in checking for file #{url}: #{e.message}"
      return false
    end

    def get_frontend_url_for(opt = {})
      opt[:host] ||= CONFIG['external_frontend_host'] || CONFIG['frontend_host']
      opt[:port] ||= CONFIG['external_frontend_port'] || CONFIG['frontend_port']
      opt[:protocol] ||= CONFIG['external_frontend_protocol'] || CONFIG['frontend_protocol']

      unless opt[:controller]
        logger.error 'No controller given for get_frontend_url_for().'
        return
      end

      "#{opt[:protocol]}://#{opt[:host]}:#{opt[:port]}/#{opt[:controller]}"
    end
  end
end
