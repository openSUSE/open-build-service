require "socket"

class TCPSocket
  attr_accessor :connection_status
  attr_accessor :internal_buffer
  def initialize ip,port
    @internal_buffer = []
  end

  def trigger

  end

  def self.open server_ip

  end

  def setsockopt *args; end

  def >> crap
    @internal_buffer << Marshal.dump(crap)
  end

  def read
    @internal_buffer.shift
  end

  def write crap; end


  def close
    @connection_status = :closed
  end
end
