module Backend
  class Test
    # Module that holds methods for running the different parts of the backend server
    module Tasks
      def run_scheduler(arch)
        execute_backend_daemon(name: "scheduler(#{arch})", command: "./bs_sched --testmode #{arch}")
      end

      def run_publisher
        execute_backend_daemon(name: 'publisher', command: './bs_publish --testmode')
      end

      def run_deltastore
        execute_backend_daemon(name: 'deltastore', command: './bs_deltastore --testmode')
      end

      def run_admin(args)
        Rails.logger.debug 'run admin'
        ret = -1
        perlopts = "-I#{Rails.root.join('../backend')} -I#{Rails.root.join('../backend/build')}"
        IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_admin #{args}") do |io|
          io.each { |line| Rails.logger.debug { "bs_admin: #{line.strip.chomp}" } if line.present? }
          io.close
          ret = $CHILD_STATUS
        end
        ret
      end

      private

      def execute_backend_daemon(name:, command:)
        Rails.logger.debug { "run #{name}" }
        perlopts = "-I#{Rails.root.join('../backend')} -I#{Rails.root.join('../backend/build')}"
        IO.popen("cd #{backend_config}; exec perl #{perlopts} #{command}") do |io|
          io.each_line { |line| Rails.logger.debug { "#{name}: #{line.strip.chomp}" } if line.present? }
        end
      end
    end
  end
end
