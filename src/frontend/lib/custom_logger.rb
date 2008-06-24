#defines a custom formatter for all log messages

class Logger
  #revert rails logger hack
  alias format_message old_format_message

  class CustomFormatter < Formatter
    def call(severity, time, progname, msg)
      "[%s|#%5d] %s\n" % [severity[0..0], $$, msg2str(msg)]
    end
  end
end
