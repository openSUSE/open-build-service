# The backend shares (a subset of) our API routes. This is a service to proxy requests to those routes.
# It caches incoming/outgoing files in our tmp directory or makes use of the various forward/rewrite/redirect
# plugins for apache, nginx or lighttpd if configured.
module BackendProxy
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def pass_to_backend(path_override = nil, force_get: false)
    @path_to_proxy = path_override || path_from_request

    if request.get? || request.head? || force_get
      proxy_from_backend
    elsif request.post? || request.put? || request.delete?
      proxy_to_backend
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  private

  # FIXME: This shares a lot of logic with Backend::File, should be merged.
  def proxy_from_backend
    return if use_web_server_forward

    Backend::Test.start
    backend_http = Net::HTTP.new(CONFIG['source_host'], CONFIG['source_port'])
    backend_http.read_timeout = 1000
    # we have to be careful with object life cycle. the actual data is
    # deleted once the tempfile is garbage collected, but isn't kept alive
    # as the send_file function only references the path to it. So we keep it
    # for ourselves. And once the controller is garbage collected, it should
    # be fine to unlink the data
    volleyfile = Tempfile.new('volley', Dir.tmpdir, encoding: 'ascii-8bit')
    opts = { url_based_filename: true }
    backend_http.request_get(@path_to_proxy) do |response|
      opts[:status] = response.code
      opts[:type] = response['Content-Type']
      response.read_body do |segment|
        volleyfile.write(segment)
      end
    end
    opts[:length] = volleyfile.length
    opts[:disposition] = 'inline' if ['text/plain', 'text/xml'].include?(opts[:type])
    # streaming makes it very hard for test cases to verify output
    opts[:stream] = false if Rails.env.test?
    send_file(volleyfile.path, opts)
    # close the file so it's not staying in the file system
    volleyfile.close
  end

  def proxy_to_backend
    case request.method_symbol
    when :post
      if request.form_data?
        # for form data we don't need to cache anything
        response = Backend::Connection.post(@path_to_proxy, '', 'Content-Type' => 'application/x-www-form-urlencoded')
      else
        file = cache_request_body_to_file
        response = Backend::Connection.post(@path_to_proxy, file)
        file.close!
      end
    when :put
      file = cache_request_body_to_file
      response = Backend::Connection.put(@path_to_proxy, file)
      file.close!
    when :delete
      response = Backend::Connection.delete(@path_to_proxy)
    end
    send_data(response.body, type: response.fetch('content-type'),
                             disposition: 'inline')
  end

  def use_web_server_forward
    # apache & mod_xforward case
    if CONFIG['use_xforward'] && CONFIG['use_xforward'] != 'false'
      headers['X-Forward'] = "http://#{CONFIG['source_host']}:#{CONFIG['source_port']}#{@path_to_proxy}"
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(200)
      @skip_validation = true
      return true
    end
    # lighttpd 1.5 case
    if CONFIG['x_rewrite_host']
      headers['X-Rewrite-URI'] = @path_to_proxy
      headers['X-Rewrite-Host'] = CONFIG['x_rewrite_host']
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(200)
      @skip_validation = true
      return true
    end
    # nginx case
    if CONFIG['use_nginx_redirect']
      headers['X-Accel-Redirect'] = "#{CONFIG['use_nginx_redirect']}/http/#{CONFIG['source_host']}:#{CONFIG['source_port']}#{@path_to_proxy}"
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(200)
      @skip_validation = true
      return true
    end
    false
  end

  def cache_request_body_to_file
    file = Tempfile.new('volley', Dir.tmpdir, encoding: 'ascii-8bit')
    body = request.body
    buffer = ''
    file.write(buffer) while body.read(40_960, buffer)
    file.close
    file.open
    file
  end

  def path_from_request
    path = request.path_info
    query_string = request.query_string
    if request.form_data?
      # it's uncommon, but possible that we have both
      query_string += '&' if query_string.present?
      query_string += request.raw_post
    end
    query_string = '?' + query_string if query_string.present?
    path + query_string
  end
end
