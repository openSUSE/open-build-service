require 'memprof'

class MemoryDebugger
  class Line
    attr_accessor :line, :lines, :parent

    def initialize(line)
      self.line = line
      self.lines = []
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
      log_line(logger, l, "#{prefix}  ")
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    logger = Rails.logger
    GC.start
    before = `ps -orss= -p#{$PROCESS_ID}`.to_i
    file = File.new("/tmp/memprof-#{$PROCESS_ID}.log", 'w')
    ret = Memprof.dump(file.path) do
      ret = @app.call(env)
      GC.start
      ret
    end
    file.close
    after = `ps -orss= -p#{$PROCESS_ID}`.to_i
    logger.debug "memory diff #{after - before} from #{before} to #{after}"
    file = File.new("/tmp/memprof-#{$PROCESS_ID}.log", 'r')
    ids = {}
    file.each_line do |line|
      d = JSON.parse(line)
      ids[d['_id']] = Line.new(d)
    end
    file.close
    File.delete(file.path)

    array_varmap_hash = %w[varmap hash]
    array_n1_n2_n3_block_scope_shared = %w[n1 n2 n3 block scope shared]
    ids.each do |_, d|
      type = d.line['type'] || ''
      if d.line['data']
        if array_varmap_hash.include?(type)
          d.line['data'].each do |key, value|
            d.add(ids[key])
            d.add(ids[value])
          end
        end
        if type == 'array'
          d.line['data'].each do |v|
            d.add(ids[v])
          end
        end
      end
      if type == 'scope' && d.line['variables']
        d.line['variables'].each do |key, value|
          d.add(ids[key])
          d.add(ids[value])
        end
      end
      if type == 'class' && d.line['methods']
        d.line['methods'].each do |key, value|
          d.add(ids[key])
          d.add(ids[value])
        end
      end
      if type == 'object' && d.line['ivars']
        d.line['ivars'].each do |key, value|
          d.add(ids[key])
          d.add(ids[value])
        end
      end
      array_n1_n2_n3_block_scope_shared.each do |key|
        d.add(ids[d.line[key]]) if d.line.key?(key)
      end
    end
    ids.each_value do |d|
      next unless d.parent.nil?

      log_line(logger, d)
    end
    ret
  end
end
