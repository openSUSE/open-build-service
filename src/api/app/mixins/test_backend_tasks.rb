module TestBackendTasks

  def run_scheduler(arch)
    Rails.logger.debug "RUN_SCHEDULER #{arch}"
    perlopts="-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
    IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_sched --testmode #{arch}") do |io|
      # just for waiting until scheduler finishes
      io.each { |line| Rails.logger.debug("scheduler(#{arch}): #{line.strip.chomp}") unless line.blank? }
    end
  end

  def run_dispatcher
    Rails.logger.debug 'run dispatcher'
    perlopts="-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
    IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_dispatch --test-mode") do |io|
      # just for waiting until dispatcher finishes
      io.each { |line| Rails.logger.debug("dispatcher: #{line.strip.chomp}") unless line.blank? }
    end
  end

  def run_publisher
    Rails.logger.debug 'run publisher'
    perlopts="-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
    IO.popen("cd #{backend_config}; exec perl #{perlopts} ./bs_publish --testmode") do |io|
      # just for waiting until publisher finishes
      io.each { |line| Rails.logger.debug("publisher: #{line.strip.chomp}") unless line.blank? }
    end
  end

end
