# frozen_string_literal: true
module Backend
  class Test
    # Module that holds methods for running the different parts of the backend server
    module Tasks
      def run_scheduler(arch)
        Rails.logger.debug "RUN_SCHEDULER #{arch}"
        perlopts = "-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
        IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_sched --testmode #{arch}") do |io|
          # just for waiting until scheduler finishes
          io.each { |line| Rails.logger.debug("scheduler(#{arch}): #{line.strip.chomp}") if line.present? }
        end
      end

      def run_dispatcher
        Rails.logger.debug 'run dispatcher'
        perlopts = "-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
        IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_dispatch --testmode") do |io|
          # just for waiting until dispatcher finishes
          io.each { |line| Rails.logger.debug("dispatcher: #{line.strip.chomp}") if line.present? }
        end
      end

      def run_publisher
        Rails.logger.debug 'run publisher'
        perlopts = "-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
        IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_publish --testmode") do |io|
          # just for waiting until publisher finishes
          io.each { |line| Rails.logger.debug("publisher: #{line.strip.chomp}") if line.present? }
        end
      end

      def run_deltastore
        Rails.logger.debug 'run deltastore'
        perlopts = "-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
        IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_deltastore --testmode") do |io|
          # just for waiting until deltastore finishes
          io.each { |line| Rails.logger.debug("deltastore: #{line.strip.chomp}") if line.present? }
        end
      end

      def run_admin(args)
        Rails.logger.debug 'run admin'
        ret = -1
        perlopts = "-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
        IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_admin #{args}") do |io|
          io.each { |line| Rails.logger.debug("bs_admin: #{line.strip.chomp}") if line.present? }
          io.close
          ret = $CHILD_STATUS
        end
        ret
      end
    end
  end
end
