require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RequestController, type: :controller, vcr: true do
  render_views # NOTE: This is required otherwise Suse::Validator.validate will fail

  describe '#request_command (cmd=diff)' do
    let(:user) { create(:confirmed_user) }
    let(:bs_request) { create(:bs_request) }
    before do
      login user
    end

    context 'successful' do
      before do
        post :request_command, params: { id: bs_request.number, cmd: :diff, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'with diff_to_superseded parameter' do
      let(:another_bs_request) { create(:bs_request) }
      context 'of a not superseded request' do
        before do
          post :request_command, params: { id: bs_request.number, cmd: :diff, format: :xml, diff_to_superseded: another_bs_request }
        end

        it { expect(response).to have_http_status(:not_found) }
      end

      context 'of a superseded request' do
        before do
          another_bs_request.update(state: :superseded, superseded_by: bs_request.number)
          post :request_command, params: { id: bs_request.number, cmd: :diff, format: :xml, diff_to_superseded: another_bs_request }
        end

        it { expect(response).to have_http_status(:success) }
      end
    end
  end

  describe '#global_command (cmd=create)' do
    context 'requesting creation of a source project that has a project link that is not owned by the requester' do
      include_context 'a BsRequest that has a project link'

      it 'prohibits creation of request' do
        expect { post :global_command, params: { cmd: :create }, body: xml, format: :xml }.not_to change(BsRequest, :count)
        expect(response).to have_http_status(:forbidden)
        assert_select 'status[code=lacking_maintainership]' do
          assert_select 'summary', text: 'Creating a submit request action with options requires maintainership in source package'
        end
      end
    end
  end
end
