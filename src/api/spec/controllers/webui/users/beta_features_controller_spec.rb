require 'rails_helper'

RSpec.describe Webui::Users::BetaFeaturesController do
  describe 'when the user is anonymous' do
    before do
      get :index
    end

    it { expect(response).to have_http_status(:found) }
    it { expect(response).to redirect_to(new_session_path) }
  end
end
