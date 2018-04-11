# frozen_string_literal: true

require 'browser_helper'

RSpec.feature "User's icons", type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'moi') }

  scenario 'specifying png format' do
    visit "/user/icon/#{user.login}.png"
    expect(page.status_code).to be 200
    visit "/user/icon/#{user.login}.png?size=20"
    expect(page.status_code).to be 200
  end

  scenario 'without specifying format' do
    visit "/user/show/#{user.login}"
    expect(page.status_code).to be 200
    visit "/user/show/#{user.login}?size=20"
    expect(page.status_code).to be 200
  end
end
