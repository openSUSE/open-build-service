module Backend
  # Class that holds basic HTTP methods for connecting to the backend
  class Connection
    cattr_accessor :host, instance_accessor: false do
      CONFIG['source_host']
    end

    cattr_accessor :port, instance_accessor: false do
      CONFIG['source_port']
    end

    cattr_accessor :use_ssl, instance_accessor: false do
      CONFIG['source_protocol'] == 'https'
    end

    cattr_accessor :verify_mode, instance_accessor: false do
      if CONFIG['source_protocol_ssl_verification'] == false
        OpenSSL::SSL::VERIFY_NONE
      else
        # default with no config set
        OpenSSL::SSL::VERIFY_PEER
      end
    end

    @backend_runtime = 0

    def self.reset_runtime
      @backend_runtime = 0
    end

    def self.runtime
      @backend_runtime
    end

    def self.get(path, in_headers = {}, &)
      start_time = Time.now
      in_headers['X-Frontend-Start'] = start_time.to_i.to_s
      timeout = in_headers.delete('Timeout') || 1000
      backend_request = Net::HTTP::Get.new(path, in_headers)

      begin
        response = Net::HTTP.start(host, port, { use_ssl: use_ssl, verify_mode: verify_mode }) do |http|
          http.read_timeout = timeout
          http.request(backend_request, &)
        end
      rescue Errno::ECONNREFUSED, SocketError, Errno::ECONNRESET, Errno::EPIPE, Errno::ETIMEDOUT => e
        raise Backend::Error, "Backend unreachable: #{e.message}"
      end

      method = 'GET'
      @backend_runtime = ((Time.now - start_time) * 1000).ceil
      Backend::Instrumentation.new(method, host, response.code, @backend_runtime).instrument
      Rails.logger.info("[Backend::Connection] method=#{method} path=#{path} status=#{response.code} duration=#{@backend_runtime} user=#{User.possibly_nobody.login}")

      handle_response(response)
    end

    def self.put(path, data, in_headers = {})
      put_or_post('PUT', path, data, in_headers)
    end

    def self.post(path, data = nil, in_headers = {})
      in_headers = {
        'Content-Type' => 'application/octet-stream'
      }.merge(in_headers)
      put_or_post('POST', path, data, in_headers)
    end

    def self.delete(path, in_headers = {})
      start_time = Time.now
      in_headers['X-Frontend-Start'] = start_time.to_i.to_s
      timeout = in_headers.delete('Timeout') || 1000
      backend_request = Net::HTTP::Delete.new(path, in_headers)
      begin
        response = Net::HTTP.start(host, port, { use_ssl: use_ssl, verify_mode: verify_mode }) do |http|
          http.read_timeout = timeout
          http.request(backend_request)
        end
      rescue Errno::ECONNREFUSED, SocketError, Errno::ECONNRESET, Errno::EPIPE, Errno::ETIMEDOUT => e
        raise Backend::Error, "Backend unreachable: #{e.message}"
      end
      method = 'DELETE'
      @backend_runtime = ((Time.now - start_time) * 1000).ceil
      Backend::Instrumentation.new(method, host, response.code, @backend_runtime).instrument
      Rails.logger.info("[Backend::Connection] method=#{method} path=#{path} status=#{response.code} duration=#{@backend_runtime} user=#{User.possibly_nobody.login}")
      handle_response(response)
    end

    def self.build_query_from_hash(hash, key_list = nil)
      key_list ||= hash.keys
      query = key_list.map do |key|
        next unless hash.key?(key)

        str = hash[key].to_s
        str.toutf8

        if hash[key].nil?
          # just a boolean argument ?
          key
        elsif hash[key].is_a?(Array)
          hash[key].map { |value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
        else
          "#{key}=#{CGI.escape(hash[key].to_s)}"
        end
      end
      query.empty? ? '' : "?#{query.compact.join('&')}"
    end

    #### To define class methods as private use private_class_method
    #### private

    def self.put_or_post(method, path, data, in_headers)
      start_time = Time.now
      in_headers['X-Frontend-Start'] = start_time.to_i.to_s
      timeout = in_headers.delete('Timeout')
      backend_request = if method == 'PUT'
                          Net::HTTP::Put.new(path, in_headers)
                        else
                          Net::HTTP::Post.new(path, in_headers)
                        end
      if data.respond_to?(:read)
        backend_request.content_length = data.size
        backend_request.body_stream = data
      else
        backend_request.body = data
      end

      begin
        response = Net::HTTP.start(host, port, { use_ssl: use_ssl, verify_mode: verify_mode }) do |http|
          http.read_timeout = if method == 'POST'
                                # POST requests can be quite complicate and take some time ..
                                timeout || 100_000
                              else
                                timeout || 1000
                              end
          begin
            http.request(backend_request)
          rescue Errno::EPIPE, Errno::ECONNRESET, SocketError, Errno::EINTR, IOError, Errno::ETIMEDOUT
            raise Timeout::Error
          end
        end
      rescue Errno::ECONNREFUSED, SocketError, Errno::ECONNRESET, Errno::EPIPE, Errno::ETIMEDOUT => e
        raise Backend::Error, "Backend unreachable: #{e.message}"
      end

      @backend_runtime = ((Time.now - start_time) * 1000).ceil
      Backend::Instrumentation.new(method, host, response.code, @backend_runtime).instrument
      Rails.logger.info("[Backend::Connection] method=#{method} path=#{path} status=#{response.code} duration=#{@backend_runtime} user=#{User.possibly_nobody.login}")
      handle_response(response)
    end

    private_class_method :put_or_post

    def self.handle_response(response)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK
        response
      when Net::HTTPNotFound
        raise Backend::NotFoundError, String.new(response.read_body, encoding: 'UTF-8')
      else
        message = response.read_body
        message = response.to_s if message.blank?
        raise Backend::Error, String.new(message, encoding: 'UTF-8')
      end
    end

    private_class_method :handle_response
  end
end
