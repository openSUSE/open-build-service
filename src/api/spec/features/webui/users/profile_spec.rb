require 'browser_helper'

RSpec.describe 'User Profile', type: :feature, js: true do
  let!(:user) { create(:confirmed_user) }

  before do
    login user
    visit user_path(user)
  end

  it 'public beta program' do
    within('#beta-form') do
      find('.custom-control-label').click
    end
    expect(page).to have_text("User data for user '#{user.login}' successfully updated.")
    expect(find('#beta-switch', visible: false)).to be_checked
    expect(user.reload.in_beta).to be_truthy

    within('#beta-form') do
      find('.custom-control-label').click
    end
    expect(page).to have_text("User data for user '#{user.login}' successfully updated.")
    expect(find('#beta-switch', visible: false)).not_to be_checked
    expect(user.reload.in_beta).to be_falsey
  end
end
