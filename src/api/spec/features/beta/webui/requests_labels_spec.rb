require 'browser_helper'

RSpec.describe 'Requests labeling', :beta do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'submitter') }
  let(:maintainer) { create(:confirmed_user, login: 'maintainer') }
  let(:target_project) { create(:project, maintainer: maintainer) }
  let(:bs_request) { create(:delete_bs_request, creator: submitter, target_project: target_project) }
  let(:label_template) { create(:label_template, project: target_project) }
  let!(:label) { create(:label, label_template: label_template, labelable: bs_request) }

  before do
    Flipper.enable(:request_show_redesign)
    Flipper.enable(:labels)
  end

  context 'for maintainer' do
    before do
      login maintainer
      visit request_show_path(bs_request.number)
    end

    it 'shows labels' do
      expect(page).to have_text(label_template.name)
    end

    it 'shows set label button' do
      expect(page).to have_text('Set Labels')
    end
  end

  context 'for non-maintainers' do
    before do
      login submitter
      visit request_show_path(bs_request.number)
    end

    it 'shows labels' do
      expect(page).to have_text(label_template.name)
    end

    it 'does not show set label option' do
      expect(page).to have_no_text('Set Labels')
    end
  end
end
