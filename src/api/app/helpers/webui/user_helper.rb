module Webui::UserHelper
  def user_states_for_edit
    %w[confirmed unconfirmed deleted locked]
  end
end
