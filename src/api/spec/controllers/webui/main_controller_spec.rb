RSpec.describe Webui::MainController do
  let(:workerstatus_xml) { '<workerstatus clients="0"></workerstatus>' }
  let(:workerstatus_node) { Nokogiri::XML(workerstatus_xml).root }

  before do
    allow(WorkerStatus).to receive(:hidden).and_return(workerstatus_node)
    allow(StatisticsCalculations).to receive(:get_latest_updated).and_return([])
  end

  describe 'GET #index' do
    context 'when user is logged in' do
      let(:user) { create(:confirmed_user) }
      let!(:activity) do
        CommitActivity.create!(user: user, project: 'ProjectA', package: 'PackageB', date: Time.zone.today, count: 1)
      end

      before do
        login(user)
        get :index
      end

      it { expect(response).to have_http_status(:success) }

      it 'assigns @my_latest_updates' do
        expect(assigns(:my_latest_updates)).to contain_exactly(activity)
      end
    end

    context 'when user is not logged in' do
      before do
        get :index
      end

      it { expect(response).to have_http_status(:success) }

      it 'assigns nil to @my_latest_updates' do
        expect(assigns(:my_latest_updates)).to be_nil
      end
    end
  end
end
