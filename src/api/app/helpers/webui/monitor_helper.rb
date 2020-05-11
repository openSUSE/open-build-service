module Webui::MonitorHelper
  def self.print_statistics_array(array)
    # safe guard
    array ||= []
    '[' + array.map { |time, value| "[#{time * 1000}, #{value}]" }.join(',') + ']'
  end

  def icon_for_daemon(state)
    case state
    when 'dead'
      'fa-exclamation-circle text-danger'
    when 'booting'
      'fa-exclamation-triangle text-warning'
    else
      'fa-check-circle text-success'
    end
  end
end
