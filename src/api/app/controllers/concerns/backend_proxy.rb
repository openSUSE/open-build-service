# We share a lot of API endpoints with the backend (BSSrcServer->$dispatches)
# so we frequently just proxy/forward requests to it. This is done by calling
# the `pass_to_backend` method in other controller actions.
module BackendProxy
  extend ActiveSupport::Concern

  included do
    # Takes a request and proxies it to the Backend API.
    # Either directly with a file cache or, if configured,
    # transparently with web server specific forwarding headers.
    def pass_to_backend(path = nil)
      path ||= http_request_path

      if request.get? || request.head?
        volley_backend_path(path) unless forward_from_backend(path)
        return
      end
      case request.method_symbol
      when :post
        # for form data we don't need to download anything
        if request.form_data?
          response = Backend::Connection.post(path, '', 'Content-Type' => 'application/x-www-form-urlencoded')
        else
          file = download_request
          response = Backend::Connection.post(path, file)
          file.close!
        end
      when :put
        file = download_request
        response = Backend::Connection.put(path, file)
        file.close!
      when :delete
        response = Backend::Connection.delete(path)
      end

      text = response.body
      send_data(text, type: response.fetch('content-type'),
                      disposition: 'inline')
      text
    end
  end

  # This method is proxying GET requests manually to the backend.
  # Takes a path/query, asks the backend for a response to this,
  # saves this to a temporary file and sends this file as response.
  def volley_backend_path(path)
    logger.debug "[backend] VOLLEY: #{path}"
    backend_http = Net::HTTP.new(CONFIG['source_host'], CONFIG['source_port'])
    backend_http.read_timeout = 1000

    # we have to be careful with object life cycle. the actual data is
    # deleted once the tempfile is garbage collected, but isn't kept alive
    # as the send_file function only references the path to it. So we keep it
    # open for ourselves. And once the controller is garbage collected, it should
    # be fine to unlink the data
    @volleyfile = Tempfile.new('volley', Rails.root.join('tmp').to_s, encoding: 'ascii-8bit')
    opts = { url_based_filename: true }

    backend_http.request_get(path) do |res|
      opts[:status] = res.code
      opts[:type] = res['Content-Type']
      res.read_body do |segment|
        @volleyfile.write(segment)
      end
    end
    opts[:length] = @volleyfile.length
    opts[:disposition] = 'inline' if ['text/plain', 'text/xml'].include?(opts[:type])
    # streaming makes it very hard for test cases to verify output
    opts[:stream] = false if Rails.env.test?
    send_file(@volleyfile.path, opts)
    # close the file so it's not staying in the file system
    @volleyfile.close
  end

  # This method is proxying GET requests transparently to the backend with web server specific forwarding headers.
  # Takes a path/query and lets the web server forward the backends response.
  def forward_from_backend(path)
    # apache & mod_xforward case
    # https://build.opensuse.org/package/show/OBS:Server:Unstable/apache2-mod_xforward
    if CONFIG['use_xforward'] && CONFIG['use_xforward'] != 'false'
      logger.debug "[backend] VOLLEY(mod_xforward): #{path}"
      headers['X-Forward'] = "#{CONFIG['source_protocol'] || 'http'}://#{CONFIG['source_host']}:#{CONFIG['source_port']}#{path}"
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(:ok)
      @skip_validation = true
      return true
    end

    # https://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_ModProxyCore
    if CONFIG['x_rewrite_host']
      logger.debug "[backend] VOLLEY(lighttpd): #{path}"
      headers['X-Rewrite-URI'] = path
      headers['X-Rewrite-Host'] = CONFIG['x_rewrite_host']
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(:ok)
      @skip_validation = true
      return true
    end

    # https://www.nginx.com/resources/wiki/start/topics/examples/x-accel/
    if CONFIG['use_nginx_redirect']
      logger.debug "[backend] VOLLEY(nginx): #{path}"
      headers['X-Accel-Redirect'] = "#{CONFIG['use_nginx_redirect']}/http/#{CONFIG['source_host']}:#{CONFIG['source_port']}#{path}"
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(:ok)
      @skip_validation = true
      return true
    end

    false
  end

  # Get the path/query from ActionDispatch::Request
  # FIXME: Use request.fullpath
  def http_request_path
    path = request.path_info
    query_string = request.query_string
    if request.form_data?
      # it's uncommon, but possible that we have both
      query_string += '&' if query_string.present?
      query_string += request.raw_post
    end
    query_string = "?#{query_string}" if query_string.present?
    path + query_string
  end

  # Create a temp file from the request body for POST/PUT methods
  # FIXME: This should be merged with the implementation inside volley_backend_path
  def download_request
    file = Tempfile.new('volley', Rails.root.join('tmp').to_s, encoding: 'ascii-8bit')
    b = request.body
    buffer = ''
    file.write(buffer) while b.read(40_960, buffer)
    file.close
    file.open
    file
  end
end
