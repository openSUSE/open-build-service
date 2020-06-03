require 'browser_helper'
RSpec.describe 'Interconnects', type: :feature, js: true, vcr: true do
  let(:admin_user) { create(:admin_user) }

  it 'creating openSUSE.org interconnect' do
    login admin_user
    visit new_interconnect_path

    click_button('Connect', match: :first)

    expect(page).to have_content("Project 'openSUSE.org' was successfully created.")
    expect(RemoteProject.exists?(name: 'openSUSE.org')).to be true
  end

  it 'creating custom interconnect' do
    login admin_user
    visit new_interconnect_path

    click_button('Add')

    fill_in 'project_name', with: 'custom_packman'
    fill_in 'project_remoteurl', with: 'https://pmbs-api.links2linux.de/public'
    fill_in 'project_title', with: 'My custom Build Service Packman'
    fill_in 'project_description', with: 'This instance can be used to access resources from packman.'

    click_button('Accept')
    expect(page).to have_content("Project 'custom_packman' was successfully created.")
    expect(page).to have_current_path(project_show_path(project: 'custom_packman'))
  end
end
