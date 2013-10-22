worker_processes 4

after_fork do |server, worker|
  listener = server.config[:listeners][0]
  port = Integer(listener.split(':')[1])
  ActiveXML::api.port = port 
  CONFIG['frontend_port'] = port
end
