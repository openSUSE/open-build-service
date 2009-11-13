class TimeServer
  # the data send by client would be received here
  def receive_data(p_data)
  end

  # would be called when someone connects to the server for the
  # first time
  def post_init
    add_periodic_timer(2) { say_hello_world }
  end

  # would be called when client connection is complete.
  def connection_completed
  end

  def say_hello_world
    send_data("Hello World\n")
  end
end

# this worker is going to act like server.
class ServerWorker < BackgrounDRb::MetaWorker
  set_worker_name :server_worker
  def create(args = nil)
    # start the server when worker starts
    start_server("0.0.0.0",11009,TimeServer) do |client_connection|
      client_connection.say_hello_world
    end
  end
end

