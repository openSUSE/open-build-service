class Project::RemoteURL
  require 'open-uri'

  def self.load(remote_project, path)
    if File.file?('/etc/sysconfig/proxy')
      proxysettings = Hash[File.read('/etc/sysconfig/proxy').scan(/(\S+)\s*=\s*"([^"]+)/)]
      Rails.logger.info "var HTTP_PROXY: #{proxysettings.fetch("HTTP_PROXY")} var HTTPS_PROXY: #{proxysettings.fetch("HTTPS_PROXY")} var NO_PROXY: #{proxysettings.fetch("NO_PROXY")}"
      ENV['http_proxy'] = proxysettings.fetch("HTTPS_PROXY") if proxysettings.has_key?("HTTPS_PROXY")
      ENV['https_proxy'] = proxysettings.fetch("HTTPS_PROXY") if proxysettings.has_key?("HTTPS_PROXY")
      ENV['ftp_proxy'] = proxysettings.fetch("HTTPS_PROXY") if proxysettings.has_key?("FTP_PROXY")
      ENV['no_Proxy'] = proxysettings.fetch("NO_PROXY") if proxysettings.has_key?("NO_PROXY")
    end

    uri = URI.parse(remote_project.remoteurl + path)
    # prefer environment variables if set
    ENV['http_proxy'] = Configuration.first.http_proxy if ENV['http_proxy'].blank?
    ENV['https_proxy'] = Configuration.first.http_proxy if ENV['https_proxy'].blank?
    ENV['no_proxy'] = Configuration.first.no_proxy if ENV['no_proxy'].blank?
    Rails.logger.info "uri: #{uri} proxy: #{ENV['http_proxy']}"
    begin
      uri.open.read
    rescue OpenURI::HTTPError, SocketError, Errno::EINTR, Errno::EPIPE, EOFError, Net::HTTPBadResponse, IOError, Errno::ENETUNREACH,
           Errno::EADDRNOTAVAIL, Errno::ETIMEDOUT, Errno::ECONNREFUSED, Timeout::Error, OpenSSL::SSL::SSLError => e
      Rails.logger.info "#{e} when fetching #{path} from #{remote_project.remoteurl}"
      Airbrake.notify(e)
      nil
    end
  end
end
