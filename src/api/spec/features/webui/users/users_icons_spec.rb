require 'browser_helper'

RSpec.feature "User's icons", type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'moi') }

  scenario 'specifying icon' do
    visit "/user/#{user.login}/icon"
    expect(page.status_code).to be 200
    visit "/user/#{user.login}/icon?size=20"
    expect(page.status_code).to be 200
  end

  scenario 'without specifying format' do
    visit "/user/show/#{user.login}"
    expect(page.status_code).to be 200
    visit "/user/show/#{user.login}?size=20"
    expect(page.status_code).to be 200
  end
end
