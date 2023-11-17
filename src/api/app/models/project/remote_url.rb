class Project::RemoteURL
  require 'open-uri'

  def self.load(remote_project, path)
    if File.file?('/etc/sysconfig/proxy')
      proxysettings = File.read('/etc/sysconfig/proxy').scan(/(\S+)\s*=\s*"([^"]+)/).to_h
      Rails.logger.info "HTTP_PROXY: #{proxysettings['HTTP_PROXY']} NO_PROXY: #{proxysettings['NO_PROXY']}"
      ENV['http_proxy'] = proxysettings['HTTP_PROXY']
      ENV['no_proxy'] = proxysettings['NO_PROXY']
    end

    uri = URI.parse(remote_project.remoteurl + path)
    # prefer environment variables if set
    ENV['http_proxy'] = Configuration.first.http_proxy if ENV.fetch('http_proxy').blank?
    ENV['no_proxy'] = Configuration.first.no_proxy if ENV.fetch('no_proxy').blank?
    Rails.logger.info "uri: #{uri} proxy: #{ENV.fetch('http_proxy')}"
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
