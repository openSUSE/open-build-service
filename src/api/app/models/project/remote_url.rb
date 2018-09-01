module Project::RemoteURL

  def load(remote_uri, path)
    uri = URI.parse(remote_uri + path)
    http = nil
    content = nil
    proxyuri = ENV['http_proxy']
    proxyuri = CONFIG['http_proxy'] if CONFIG['http_proxy'].present?
    noproxy = ENV['no_proxy']
    noproxy = CONFIG['no_proxy'] if CONFIG['no_proxy'].present?

    noproxy_applies = false
    if noproxy
      np_split = noproxy.split(',')
      noproxy_applies = np_split.any? { |np| uri.host.end_with?(np.strip) }
    end

    if proxyuri && noproxy_applies == false
      proxy = URI.parse(proxyuri)
      proxy_user, proxy_pass = proxy.userinfo.split(/:/) if proxy.userinfo
      http = Net::HTTP::Proxy(proxy.host, proxy.port, proxy_user, proxy_pass).new(uri.host, uri.port)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end
    http.use_ssl = (uri.scheme == 'https')
    begin
      http.start
      response = http.get uri.request_uri
      content = response.body if response.is_a?(Net::HTTPSuccess)
    rescue SocketError, Errno::EINTR, Errno::EPIPE, EOFError, Net::HTTPBadResponse, IOError, Errno::ENETUNREACH,
           Errno::ETIMEDOUT, Errno::ECONNREFUSED, Timeout::Error => err
      Rails.logger.debug "#{err} when fetching #{uri}"
      http = nil
    end
    http.finish if http && http.started?
    content
  end

end
