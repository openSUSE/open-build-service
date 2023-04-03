require 'browser_helper'

RSpec.describe 'Request with delete actions', beta: true do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'submitter') }
  let(:receiver) { create(:confirmed_user, :with_home, login: 'receiver') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package, name: 'package_1', project: target_project) }
  let(:request) { create(:delete_bs_request, creator: submitter, target_project: target_project) }
  let!(:delete_package_action) do
    create(:bs_request_action_delete,
           bs_request: request,
           target_project: target_project,
           target_package: target_package)
  end

  before do
    login receiver
    visit request_show_path(request.number)
  end

  it 'shows delete actions' do
    expect(page).to have_text('Showing #1 (of 2)').and(have_text("Delete project #{target_project}"))

    click_link('Next')

    expect(page).to have_text('Showing #2 (of 2)').and(have_text("Delete package #{target_project} / #{target_package}"))
  end
end
