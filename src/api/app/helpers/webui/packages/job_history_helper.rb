module Webui::Packages::JobHistoryHelper
  def html_class_for_state(state)
    case state
    when 'succeeded'
      'text-success'
    when 'failed'
      'text-danger'
    end
  end
end
