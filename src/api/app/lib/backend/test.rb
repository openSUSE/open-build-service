module Backend
  # Class that holds methods for starting the backend server in test mode
  class Test
    @backend = nil

    # Starts the test backend
    def self.start(options = {})
      return unless Rails.env.test?
      return if @backend
      return if ENV['BACKEND_STARTED']

      print 'Starting test backend...'
      @backend = IO.popen(Rails.root.join('script/start_test_backend').to_s)
      Rails.logger.debug { "Test backend started with pid: #{@backend.pid}" }
      loop do
        line = @backend.gets
        raise 'Backend died' unless line
        break if line.include?('DONE NOW')

        Rails.logger.debug line.strip
      end
      puts 'done'
      CONFIG['global_write_through'] = true
      WebMock.disable_net_connect!(allow_localhost: true)
      ENV['BACKEND_STARTED'] = '1'
      at_exit do
        puts 'Killing test backend'
        Process.kill 'INT', @backend.pid
        @backend = nil
      end

      # make sure it's actually tried to start
      return unless options[:wait_for_scheduler]

      Rails.logger.debug 'Wait for scheduler thread to finish start'
      counter = 0
      marker = Rails.root.join('tmp/scheduler.done')
      while counter < 100
        return if ::File.exist?(marker)

        sleep(0.5)
        counter += 1
      end
    end

    # Avoid starting the test backend again
    def self.do_not_start_test_backend
      @backend = :dont
    end

    # Run the block code deactivating the global_write_through flag
    def self.without_global_write_through
      before = CONFIG['global_write_through']
      CONFIG['global_write_through'] = false
      yield
    ensure
      CONFIG['global_write_through'] = before
    end
  end
end
