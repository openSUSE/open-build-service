class Project::RemoteURL
  require 'open-uri'

  def self.load(remote_project, path)
    uri = URI.parse(remote_project.remoteurl + path)
    # prefer environment variables if set
    ENV['http_proxy'] = Configuration.http_proxy if ENV['http_proxy'].blank?
    ENV['https_proxy'] = Configuration.http_proxy if ENV['https_proxy'].blank?
    ENV['no_proxy'] = Configuration.no_proxy if ENV['no_proxy'].blank?
    begin
      uri.open.read
    rescue OpenURI::HTTPError, SocketError, Errno::EINTR, Errno::EPIPE, Net::HTTPBadResponse, IOError, Errno::ENETUNREACH,
           Errno::EADDRNOTAVAIL, Errno::ETIMEDOUT, Errno::ECONNREFUSED, Timeout::Error, OpenSSL::SSL::SSLError => e
      Rails.logger.info "#{e} when fetching #{path} from #{remote_project.remoteurl}"
      Airbrake.notify(e)
      nil
    end
  end
end
