require 'net/http'
require 'benchmark'
require 'api_exception'

module Backend
  class Connection
    @source_host = CONFIG['source_host']
    @source_port = CONFIG['source_port']

    @backend_logger = Logger.new("#{Rails.root}/log/backend_access.log")
    @backend_time = 0

    def initialize
      Rails.logger.debug "init backend"
    end

    class << self
      attr_accessor :source_host, :source_port

      def host
        @source_host
      end

      def port
        @source_port
      end

      def runtime
        @backend_time
      end

      def reset_runtime
        @backend_time = 0
      end

      def logger
        Rails.logger
      end

      def get(path, in_headers = {})
        start_test_backend
        @start_of_last = Time.now
        logger.debug "[backend] GET: #{path}"
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

        write_backend_log "GET", host, port, path, response
        handle_response response
      end

      def put_or_post(method, path, data, in_headers)
        start_test_backend
        @start_of_last = Time.now
        logger.debug "[backend] #{method}: #{path}"
        timeout = in_headers.delete('Timeout')
        if method == "PUT"
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
          if method == "POST"
            # POST requests can be quite complicate and take some time ..
            http.read_timeout = timeout || 100000
          else
            http.read_timeout = timeout || 1000
          end
          begin
            http.request backend_request
          # rubocop:disable Lint/ShadowedException
          rescue Errno::EPIPE, Errno::ECONNRESET, SocketError, Errno::EINTR, EOFError, IOError, Errno::ETIMEDOUT
            raise Timeout::Error
          end
          # rubocop:enable Lint/ShadowedException
        end
        write_backend_log method, host, port, path, response
        handle_response response
      end

      def put(path, data, in_headers = {})
        put_or_post("PUT", path, data, in_headers)
      end

      def post(path, data = nil, in_headers = {})
        in_headers = {
            'Content-Type' => 'application/octet-stream'
        }.merge in_headers
        put_or_post("POST", path, data, in_headers)
      end

      def delete(path, in_headers = {})
        start_test_backend
        @start_of_last = Time.now
        logger.debug "[backend] DELETE: #{path}"
        timeout = in_headers.delete('Timeout') || 1000
        backend_request = Net::HTTP::Delete.new(path, in_headers)
        response = Net::HTTP.start(host, port) do |http|
          http.read_timeout = timeout
          http.request backend_request
        end
        write_backend_log "DELETE", host, port, path, response
        handle_response response
        # do_delete(source_host, source_port, path)
      end

      alias_method :get_source, :get
      alias_method :put_source, :put
      alias_method :post_source, :post
      alias_method :delete_source, :delete

      def build_query_from_hash(hash, key_list = nil)
        key_list ||= hash.keys
        query = key_list.map do |key|
          if hash.has_key?(key)
            str = hash[key].to_s
            str.toutf8

            if hash[key].nil?
              # just a boolean argument ?
              [hash[key]].flat_map { key }.join("&")
            else
              [hash[key]].flat_map { "#{key}=#{CGI.escape(hash[key].to_s)}" }.join("&")
            end
          end
        end
        query.empty? ? "" : "?#{query.compact.join('&')}"
      end

      private

      def now
        Time.now.strftime "%Y%m%dT%H%M%S"
      end

      def write_backend_log(method, host, port, path, response)
        raise "write backend log without start time" unless @start_of_last
        timedelta = Time.now - @start_of_last
        @start_of_last = nil
        @backend_logger.info "#{now} #{method} #{host}:#{port}#{path} #{response.code} #{timedelta}"
        @backend_time += timedelta
        logger.debug "request took #{timedelta} #{@backend_time}"

        return unless CONFIG['extended_backend_log']

        data = response.body
        if data.nil?
          @backend_logger.info "(no data)"
        elsif data.class == 'String' && data[0, 1] == "<"
          @backend_logger.info data
        else
          @backend_logger.info "(non-XML data) #{data.class}"
        end
      end

      def handle_response(response)
        case response
        when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK
          return response
        when Net::HTTPNotFound
          raise ActiveXML::Transport::NotFoundError, response.read_body.force_encoding("UTF-8")
        else
          message = response.read_body
          message = response.to_s if message.blank?
          raise ActiveXML::Transport::Error, message.force_encoding("UTF-8")
        end
      end

      @backend = nil

      public

      def without_global_write_through
        before = CONFIG['global_write_through']
        CONFIG['global_write_through'] = false

        yield

      ensure
        CONFIG['global_write_through'] = before
      end

      def test_backend?
        (!@backend.nil? && @backend != :dont)
      end

      def do_not_start_test_backend
        @backend = :dont
      end

      def start_test_backend
        # do_not_start_test_backend
        return unless Rails.env.test?
        return if @backend
        return if ENV['BACKEND_STARTED']
        print "Starting test backend..."
        @backend = IO.popen("#{Rails.root}/script/start_test_backend")
        logger.debug "Test backend started with pid: #{@backend.pid}"
        loop do
          line = @backend.gets
          raise 'Backend died' unless line
          break if line =~ /DONE NOW/
          logger.debug line.strip
        end
        puts "done"
        CONFIG['global_write_through'] = true
        WebMock.disable_net_connect!(allow_localhost: true)
        ENV['BACKEND_STARTED'] = '1'
        at_exit do
          puts "Killing test backend"
          Process.kill "INT", @backend.pid
          @backend = nil
        end
      end

      def wait_for_scheduler_start
        # make sure it's actually tried to start
        start_test_backend
        Rails.logger.debug 'Wait for scheduler thread to finish start'
        counter = 0
        marker = Rails.root.join('tmp', 'scheduler.done')
        while counter < 100
          return if ::File.exist?(marker)
          sleep 0.5
          counter += 1
        end
      end
    end
  end
end
