module Webui::UserHelper
  def user_states_for_edit
    ['confirmed', 'unconfirmed', 'deleted', 'locked']
  end
end
