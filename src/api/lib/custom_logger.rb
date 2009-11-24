#defines a custom formatter for all log messages

class NiceLogger < Logger

  def format_message(severity, timestamp, progname, msg)
    "[%s|#%5d] %s\n" % [severity[0..0], $$, msg]
  end

end
