require 'spec_helper'

RSpec.describe 'Interconnect', type: :feature do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it 'should be able to create link' do
    visit '/interconnects/new'
    within('div[data-interconnect="openSUSE.org"]') do
      click_button('Connect')
    end
    using_wait_time 10 do
      click_link('openSUSE.org')
    end

    expect(page).to have_content('Standard OBS instance at build.opensuse.org')
    expect(page).to have_content('https://api.opensuse.org/public')
  end
end
