#defines a custom formatter for all log messages

class NiceLogger < Logger

  def format_message(severity, timestamp, progname, msg)
    out=""
    while msg[0] == 13 or msg[0] == 10
      out = out.concat(msg[0])
      msg = msg[1..-1]
    end
   
    out + "[%s|#%5d] %s\n" % [severity[0..0], $$, msg]
  end

  # def format_message(severity, timestamp, msg, progname)
  #   "#{timestamp.strftime("%b %d %H:%M:%S")} #{Socket.gethostname.split('.').first} rails[#{$PID}]: #{progname.gsub(/\n/, '').lstrip}\n"
  # end

end
