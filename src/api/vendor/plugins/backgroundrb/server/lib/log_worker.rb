class LogWorker < Packet::Worker
  set_worker_name :log_worker
  attr_accessor :log_file
  def worker_init
    @log_file = Logger.new("#{RAILS_HOME}/log/backgroundrb_#{BDRB_CONFIG[:backgroundrb][:port]}.log")
  end

  def receive_data p_data
    case p_data[:type]
    when :request: process_request(p_data)
    when :response: process_response(p_data)
    end
  end

  def process_request(p_data)
    log_data = p_data[:data]
    @log_file.info(log_data)
  end

  def process_response
    puts "Not implemented and needed"
  end
end


