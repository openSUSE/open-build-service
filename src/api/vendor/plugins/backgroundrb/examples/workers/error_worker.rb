# Put your code that runs your task inside the do_work method it will be
# run automatically in a thread. You have access to all of your rails
# models.  You also get logger and results method inside of this class
# by default.
class ErrorWorker < BackgrounDRb::MetaWorker
  set_worker_name :error_worker
  set_no_auto_load(true)

  def create(args = nil)
    logger.info "creating error worker"
  end

  def hello_world(data)
    logger.info "invoking #{worker_name} hello world #{data} #{Time.now}"
  end
end

