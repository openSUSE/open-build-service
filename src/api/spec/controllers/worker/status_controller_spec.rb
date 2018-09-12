require 'rails_helper'

RSpec.describe Worker::StatusController, vcr: true do
  render_views

  let(:user) { create(:confirmed_user) }

  before do
    login user
  end

  describe 'GET /index' do
    subject! { get :index, params: { format: :xml } }

    it { is_expected.to have_http_status(:success) }
    it { assert_select 'workerstatus[clients=2]' }
  end
end
