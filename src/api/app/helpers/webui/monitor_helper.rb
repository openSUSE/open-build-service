# frozen_string_literal: true
module Webui::MonitorHelper
  def self.print_statistics_array(array)
    # safe guard
    array ||= []
    '[' + array.map { |time, value| "[#{time * 1000}, #{value}]" }.join(',') + ']'
  end
end
