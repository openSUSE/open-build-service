require 'browser_helper'

RSpec.describe 'Review with Canned Responses', :js, :vcr do
  let(:reviewer) { create(:confirmed_user, :with_home, login: 'reviewer') }
  let(:submitter) { create(:confirmed_user, :with_home, login: 'submitter') }
  let(:source_project) { create(:project_with_package, name: 'source_project', package_name: 'ball', maintainer: reviewer) }
  let(:source_package) { source_project.packages.first }
  let(:target_project) { create(:project_with_package, name: 'target_project', package_name: 'goal', maintainer: submitter) }

  let(:bs_request) do
    create(:bs_request_with_submit_action,
           creator: submitter,
           target_project: target_project,
           source_project: source_project,
           source_package: source_package,
           review_by_user: reviewer.login)
  end
  let!(:canned_response) { create(:canned_response, user: reviewer, title: 'Looks good', content: 'Reviewed and approved.') }

  before do
    Flipper.enable(:request_show_redesign)
    Flipper.enable(:canned_responses)
    login reviewer
    visit request_show_path(number: bs_request.number)
  end

  it 'inserts canned response into review comment textarea and submits successfully' do
    # Open review form
    within '#add-review-dropdown-component' do
      find('div', text: 'Review').click
      find('div', text: 'reviewer').click
    end

    # Click Canned Responses dropdown and select a response
    within '#review-form-collapse' do
      find_button('Canned Responses').click
      within '.dropdown-menu' do
        find('li', text: 'Looks good').click
      end
    end

    # Verify textarea was populated
    expect(find_field('comment').value).to eq('Reviewed and approved.')

    # Select Approve and submit
    choose('Approve')
    click_button('Submit review')

    expect(page).to have_text('Successfully submitted review')
  end
end
