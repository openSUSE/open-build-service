# frozen_string_literal: true

worker_processes 4
listen 3000

after_fork do |server, _|
  listener = server.listener_opts.first[0]
  port = Integer(listener.split(':')[1])
  ActiveXML.api.port = port
  CONFIG['frontend_port'] = port
end
