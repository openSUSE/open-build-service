require 'memprof'

class MemoryDebugger
  class Line
    attr_accessor :line, :lines, :parent
    def initialize(line)
      self.line = line
      self.lines = Array.new
    end

    def add(line)
      return if line.nil?
      return unless line.parent.nil?
      return unless check_up(line)
      line.parent = self
      lines << line
    end

    def check_up(line)
      return false if self == line
      return true unless parent
      parent.check_up(line)
    end
  end

  def log_line(logger, d, prefix = '')
    logger.debug prefix + d.line.inspect
    d.lines.each do |l|
      log_line(logger, l, prefix + '  ')
    end
  end

  def initialize(app)
    @app=app
  end

  def call(env)
    logger = Rails.logger
    GC.start
    before=%x(ps -orss= -p#{$$}).to_i
    file = File.new("/tmp/memprof-#{$$}.log", "w")
    ret = Memprof.dump(file.path) do
      ret = @app.call(env)
      GC.start
      ret
    end
    file.close
    after=%x(ps -orss= -p#{$$}).to_i
    logger.debug "memory diff #{after-before} from #{before} to #{after}"
    file = File.new("/tmp/memprof-#{$$}.log", "r")
    ids = Hash.new
    file.each_line do |line|
      d = JSON.parse(line)
      ids[d['_id']] = Line.new(d)
    end
    file.close
    File.delete(file.path)

    ids.each do |_, d|
      type = d.line['type'] || ''
      if d.line["data"]
	d.line["data"].each do |key, value|
	  d.add(ids[key])
	  d.add(ids[value])
	end if type == 'varmap' || type == 'hash'
	d.line["data"].each do |v|
	  d.add(ids[v])
	end if type == "array"
      end
      if type == "scope"
	d.line["variables"].each do |key, value|
	  d.add(ids[key])
	  d.add(ids[value])
	end if d.line["variables"]
      end
      if type == "class"
	d.line["methods"].each do |key, value|
	  d.add(ids[key])
	  d.add(ids[value])
	end if d.line["methods"]
      end
      if type == "object"
	d.line["ivars"].each do |key, value|
	  d.add(ids[key])
	  d.add(ids[value])
	end if d.line["ivars"]
      end
      %w(n1 n2 n3 block scope shared).each do |key|
	if d.line.has_key?(key)
	  d.add(ids[d.line[key]])
	end
      end
    end
    ids.each_value do |d|
      next unless d.parent.nil?
      log_line(logger, d)
    end
    ret
  end
end
