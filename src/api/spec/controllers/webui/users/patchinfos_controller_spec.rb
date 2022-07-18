require 'rails_helper'

RSpec.describe Webui::Users::PatchinfosController do
  describe 'GET #index' do
    it { is_expected.to use_after_action(:verify_authorized) }
  end
end
