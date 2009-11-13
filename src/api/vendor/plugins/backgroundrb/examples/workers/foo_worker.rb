# Put your code that runs your task inside the do_work method it will be
# run automatically in a thread. You have access to all of your rails
# models.  You also get logger and results method inside of this class
# by default.

class TimeClient
  def receive_data(p_data)
    worker.get_external_data(p_data)
  end

  def post_init
    p "***************** : connection completed"
  end
end

class FooWorker < BackgrounDRb::MetaWorker
  set_worker_name :foo_worker
  def create(args = nil)
    #register_status("Running")
    add_periodic_timer(10) { foobar }
    external_connection = nil
    connect("localhost",11009,TimeClient) { |conn| external_connection = conn }
  end

  def get_external_data(p_data)
    cache[some_key] = p_data
  end

  def foobar
    cache[some_key] = "Time is now : #{Time.now}"
  end

  def barbar(data)
    logger.info "invoking babrbar on #{Time.now} #{data}"
  end

end

