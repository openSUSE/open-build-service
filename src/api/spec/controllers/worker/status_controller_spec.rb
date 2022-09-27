require 'rails_helper'

RSpec.describe Worker::StatusController, vcr: true do
  render_views

  let(:user) { create(:confirmed_user) }

  before do
    login user
  end

  describe 'GET /index' do
    let(:worker_status_response) { file_fixture('worker_status_response.xml') }

    before do
      stub_request(:get, CONFIG['source_url'] + '/build/_workerstatus').and_return(body: worker_status_response)
    end

    subject! { get :index, params: { format: :xml } }

    it { is_expected.to have_http_status(:success) }

    it 'finds 2 workers' do
      expect(response.body).to have_selector('workerstatus[clients=2]')
    end
  end
end
