module Backend
  # Class that holds basic HTTP methods for connecting to the backend
  class Connection
    cattr_accessor :host, instance_accessor: false do
      CONFIG['source_host']
    end

    cattr_accessor :port, instance_accessor: false do
      CONFIG['source_port']
    end

    def self.get(path, in_headers = {})
      Backend::Test.start
      start_time = Time.now
      Rails.logger.debug "[backend] GET: #{path}"
      timeout = in_headers.delete('Timeout') || 1000
      backend_request = Net::HTTP::Get.new(path, in_headers)

      response = Net::HTTP.start(host, port) do |http|
        http.read_timeout = timeout
        if block_given?
          http.request(backend_request) do |backend_response|
            yield(backend_response)
          end
        else
          http.request(backend_request)
        end
      end

      Backend::Logger.info('GET', host, port, path, response, start_time)
      handle_response(response)
    end

    def self.put(path, data, in_headers = {})
      put_or_post('PUT', path, data, in_headers)
    end

    def self.post(path, data = nil, in_headers = {})
      in_headers = {
        'Content-Type' => 'application/octet-stream'
      }.merge in_headers
      put_or_post('POST', path, data, in_headers)
    end

    def self.delete(path, in_headers = {})
      Backend::Test.start
      start_time = Time.now
      Rails.logger.debug "[backend] DELETE: #{path}"
      timeout = in_headers.delete('Timeout') || 1000
      backend_request = Net::HTTP::Delete.new(path, in_headers)
      response = Net::HTTP.start(host, port) do |http|
        http.read_timeout = timeout
        http.request(backend_request)
      end
      Backend::Logger.info('DELETE', host, port, path, response, start_time)
      handle_response(response)
    end

    def self.build_query_from_hash(hash, key_list = nil)
      key_list ||= hash.keys
      query = key_list.map do |key|
        if hash.has_key?(key)
          str = hash[key].to_s
          str.toutf8

          if hash[key].nil?
            # just a boolean argument ?
            [hash[key]].flat_map { key }.join('&')
          else
            [hash[key]].flat_map { "#{key}=#{CGI.escape(hash[key].to_s)}" }.join('&')
          end
        end
      end
      query.empty? ? '' : "?#{query.compact.join('&')}"
    end

    #### To define class methods as private use private_class_method
    #### private

    def self.put_or_post(method, path, data, in_headers)
      Backend::Test.start
      start_time = Time.now
      Rails.logger.debug "[backend] #{method}: #{path}"
      timeout = in_headers.delete('Timeout')
      if method == 'PUT'
        backend_request = Net::HTTP::Put.new(path, in_headers)
      else
        backend_request = Net::HTTP::Post.new(path, in_headers)
      end
      if data.respond_to?('read')
        backend_request.content_length = data.size
        backend_request.body_stream = data
      else
        backend_request.body = data
      end

      response = Net::HTTP.start(host, port) do |http|
        if method == 'POST'
          # POST requests can be quite complicate and take some time ..
          http.read_timeout = timeout || 100000
        else
          http.read_timeout = timeout || 1000
        end
        begin
          http.request(backend_request)
        # rubocop:disable Lint/ShadowedException
        rescue Errno::EPIPE, Errno::ECONNRESET, SocketError, Errno::EINTR, EOFError, IOError, Errno::ETIMEDOUT
          raise Timeout::Error
        end
        # rubocop:enable Lint/ShadowedException
      end
      Backend::Logger.info(method, host, port, path, response, start_time)
      handle_response(response)
    end

    private_class_method :put_or_post

    def self.handle_response(response)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK
        return response
      when Net::HTTPNotFound
        raise ActiveXML::Transport::NotFoundError, response.read_body.force_encoding('UTF-8')
      else
        message = response.read_body
        message = response.to_s if message.blank?
        raise ActiveXML::Transport::Error, message.force_encoding('UTF-8')
      end
    end

    private_class_method :handle_response
  end
end
