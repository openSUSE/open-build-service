require 'openssl'

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

    def self.ssl_options()
      unless @@ssl_options
        ## TODO: check if this really works. we should cache this in a class variable
        ##       so we do not have to do this over and over

        # the old default value for ssl_options
        @@ssl_options ||= { use_ssl: use_ssl, verify_mode: verify_mode }

        # Handle client certificates
        if CONFIG['source_host_client_certificate']

          cert_data = File.read(CONFIG['source_host_client_certificate'])
          ssl_options[:cert] = OpenSSL::X509::Certificate.new(cert_data)

          # if you concatenate key and cert into one file you do not need to pass in source_client_key
          # and we can reuse the cert_data here.
          if File.read(CONFIG['source_host_client_certificate_key']
            key_data = File.read(CONFIG['source_host_client_certificate_key'])
          else
            key_data = cert_data
          end

          if CONFIG['source_host_client_certificate_password']
            ssl_options[:key] = OpenSSL::PKey.read(key_data, CONFIG['source_host_client_certificate_password'])
          else
            ssl_options[:key] = OpenSSL::PKey.read(key_data)
          end
        end

      end
      return @@ssl_options
    end

    def self.get(path, in_headers = {})
      start_time = Time.now
      Rails.logger.debug { "[backend] GET: #{path}" }
      timeout = in_headers.delete('Timeout') || 1000
      backend_request = Net::HTTP::Get.new(path, in_headers)

      response = Net::HTTP.start(host, port, Backend::Connection.ssl_options) do |http|
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
      }.merge(in_headers)
      put_or_post('POST', path, data, in_headers)
    end

    def self.delete(path, in_headers = {})
      start_time = Time.now
      Rails.logger.debug { "[backend] DELETE: #{path}" }
      timeout = in_headers.delete('Timeout') || 1000
      backend_request = Net::HTTP::Delete.new(path, in_headers)
      response = Net::HTTP.start(host, port, Backend::Connection.ssl_options) do |http|
        http.read_timeout = timeout
        http.request(backend_request)
      end
      Backend::Logger.info('DELETE', host, port, path, response, start_time)
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
      Rails.logger.debug { "[backend] #{method}: #{path}" }
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

      response = Net::HTTP.start(host, port, Backend::Connection.ssl_options) do |http|
        http.read_timeout = if method == 'POST'
                              # POST requests can be quite complicate and take some time ..
                              timeout || 100_000
                            else
                              timeout || 1000
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
        response
      when Net::HTTPNotFound
        raise Backend::NotFoundError, response.read_body.force_encoding('UTF-8')
      else
        message = response.read_body
        message = response.to_s if message.blank?
        raise Backend::Error, message.force_encoding('UTF-8')
      end
    end

    private_class_method :handle_response
  end
end
