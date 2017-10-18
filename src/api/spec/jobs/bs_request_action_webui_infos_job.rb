require 'rails_helper'

RSpec.describe BsRequestActionWebuiInfosJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:request_action) { create(:bs_request_action) }

    before do
      allow(BsRequestAction).to receive(:find).and_return(request_action)
      allow(request_action).to receive(:webui_infos)
    end

    subject! { BsRequestActionWebuiInfosJob.new.perform(request_action) }

    it 'calls webui_infos on the request_action' do
      expect(request_action).to have_received(:webui_infos)
    end
  end
end
