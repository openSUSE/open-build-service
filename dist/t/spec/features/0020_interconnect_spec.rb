require 'spec_helper'

RSpec.describe 'Interconnect', type: :feature do
  # We consciously want the state of a finished spec to be preserved for the next one
  before(:context) do # rubocop:disable RSpec/BeforeAfterAll
    login
  end

  after(:context) do # rubocop:disable RSpec/BeforeAfterAll
    logout
  end

  it 'is able to create link' do
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
