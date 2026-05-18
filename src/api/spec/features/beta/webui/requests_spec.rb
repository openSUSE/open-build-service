require 'browser_helper'

RSpec.describe 'Requests', :vcr do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
  let(:target_project) { receiver.home_project }

  # a partial view for each request action type must exist
  let(:required_files) do
    BsRequestAction::TYPES.map do |type|
      "app/views/webui/request/_changes_#{type}.html.haml"
    end
  end

  context 'a user requests a role addition on a project' do
    before do
      login submitter
      visit project_show_path(project: target_project)
      desktop? ? click_on('Request Role Addition') : click_menu_link('Actions', 'Request Role Addition')
      choose 'Bugowner'
      choose 'User'
      fill_in 'User:', with: submitter.login.to_s
      fill_in 'Description:', with: 'I can fix bugs too.'
    end

    it 'can be submitted' do
      click_button('Request')

      expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants to get the role bugowner for project #{target_project}")
      expect(page).to have_css('#description-text', text: 'I can fix bugs too.')
      expect(page).to have_css('.badge', text: 'new')
      expect(BsRequest.where(creator: submitter.login, description: 'I can fix bugs too.')).to exist
    end
  end

  context 'with a group review', :js do
    let(:review_member) { create(:confirmed_user, login: 'review_member') }
    let(:another_review_member) { create(:confirmed_user, login: 'another_review_member') }
    let(:review_group) { create(:group, title: 'factory-staging', users: [review_member, another_review_member]) }
    let(:bs_request) { create(:delete_bs_request, creator: submitter, target_project: target_project) }
    let(:review) { create(:review, by_group: review_group.title, bs_request: bs_request) }
    let(:modal_id) { "review-group-members-#{review.id}-modal" }

    before do
      review
      login submitter
      visit request_show_path(bs_request.number)
    end

    it 'opens the group members modal from the reviewers list' do
      expect(page).to have_css("##{modal_id}", visible: :hidden)
      within('#side-links') { click_link review_group.title }

      within("##{modal_id}", visible: :visible) do
        expect(page).to have_css('.modal-title', text: "Members of #{review_group.title}")
      end
    end

    it 'lists the group members in the modal' do
      within('#side-links') { click_link review_group.title }

      within("##{modal_id}") do
        expect(page).to have_link(review_member.login, href: user_path(review_member))
        expect(page).to have_link(another_review_member.login, href: user_path(another_review_member))
      end
    end
  end

  it 'has all the action types partial view files' do
    missing_files = required_files.reject { |file| File.exist?(file) }

    expect(missing_files).to be_empty, <<~MSG
      The following required files are missing:
      #{missing_files.join("\n")}
    MSG
  end
end
