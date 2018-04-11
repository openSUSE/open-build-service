# frozen_string_literal: true

require 'memprof'

class MemoryDumper
  def initialize(app)
    @app = app
    @toexit = 0

    Memprof.start
    old_handler = trap('URG') do
      @toexit = 1
      old_handler.call if old_handler
    end
  end

  def call(env)
    ret = @app.call(env)
    if @toexit == 1
      pid = Process.pid
      fork do
        GC.start
        Memprof.dump_all("/tmp/memprof-#{pid}.json")
        exit!
      end
      # in case it did not work
      Process.kill('USR1', $PROCESS_ID)
      @toexit = 0
    end
    ret
  end
end
