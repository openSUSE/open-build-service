require 'rails_helper'

RSpec.describe Webui::NotificationsController do
  it { is_expected.to use_before_action(:require_admin) }
end
