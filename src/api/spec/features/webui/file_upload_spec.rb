require 'browser_helper'

RSpec.feature 'FileUpload', :type => :feature, :js => true do
  let!(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { Project.find_by(name: user.home_project_name) }
  let!(:package) { create(:package, name: 'test_package', project: home_project) }

  scenario 'uploading a kiwi.txz file creates and runs kiwi_import service' do
    login user

    visit "/package/add_file/#{home_project}/#{package}"
    expect(page).to have_content("Add File to #{package} (Project #{home_project})")

    fill_in "filename", with: "foo.kiwi.txz", :match => :first
    page.execute_script("$('#submit_button').attr('disabled', false)")
    click_button('Save changes')

    expect(current_path).to eq(package_show_path(home_project, package))
    expect(page).to have_content('config.kiwi')
  end
end
