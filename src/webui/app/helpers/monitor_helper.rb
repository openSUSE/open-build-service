module MonitorHelper

  def self.print_statistics_array array
    "[" + array.map { |time,value| "[#{time * 1000}, #{value}]"}.join(',') + "]"
  end

end


