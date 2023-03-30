require 'browser_helper'

RSpec.describe 'Request with change devel actions', beta: true, vcr: true do
  let(:submitter) { create(:confirmed_user, login: 'submitter') }
  let(:base_package) { create(:package) }
  let(:future_devel_package) { create(:package, name: base_package.name) }
  let(:request) do
    create(:bs_request_with_change_devel_action,
           source_project: future_devel_package.project,
           source_package: future_devel_package,
           target_project: base_package.project,
           target_package: base_package,
           creator: submitter)
  end

  context 'there was no previous devel package' do
    before do
      visit request_show_path(request.number)
    end

    it 'displays the description but does not mentions the previous devel package' do
      expect(page).to have_text("Set package #{future_devel_package.project} / #{future_devel_package} to be devel project/package of package #{base_package.project} / #{base_package}")
      expect(page).not_to have_text('Development is currently happening on package')
    end
  end

  context 'there was a previous devel package' do
    let(:current_devel_package) { create(:package, name: base_package.name) }

    before do
      base_package.update(develpackage: current_devel_package)
      visit request_show_path(request.number)
    end

    it 'displays the description and mentions the previous devel package' do
      expect(page).to have_text("Set package #{future_devel_package.project} / #{future_devel_package} to be devel project/package of package #{base_package.project} / #{base_package}")
      expect(page).to have_text("Development is currently happening on package #{current_devel_package.project} / #{current_devel_package}")
    end
  end
end
