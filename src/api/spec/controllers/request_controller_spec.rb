require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RequestController, type: :controller, vcr: true do
  render_views # NOTE: This is required otherwise Suse::Validator.validate will fail

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
