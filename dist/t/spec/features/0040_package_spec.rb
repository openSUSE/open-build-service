require 'spec_helper'

RSpec.describe 'Package', type: :feature do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it 'is able to create new' do
    within('#left-navigation') do
      click_link('Your Home Project')
    end
    click_link('Create Package')
    fill_in 'package_name', with: 'hello_world'
    fill_in 'package_title', with: 'hello_world'
    fill_in 'package_description', with: 'hello_world'
    click_button('Create')
    expect(page).to have_content("Package 'hello_world' was created successfully")
  end

  it 'is able to upload files' do
    within('#left-navigation') do
      click_link('Your Home Project')
    end
    click_link('hello_world')
    attach_file('files', File.expand_path('../fixtures/hello_world.spec', __dir__), make_visible: true)
    expect(page).to have_content('hello_world.spec have been successfully saved.')
  end

  it 'is able to branch' do
    within('#left-navigation') do
      click_link('Your Home Project')
    end
    click_link('Branch Package')
    fill_in 'linked_project', with: 'openSUSE.org:openSUSE:Tools'
    # In Unstable the field 'linked_package' is disabled until focus is out of 'linked_project'
    find_field('linked_package', disabled: true).click if has_field?('linked_package', disabled: true)
    fill_in 'linked_package', with: 'build'
    click_button('Branch')
    expect(page).to have_content('build.spec')
  end

  it 'is able to delete' do
    within('#left-navigation') do
      click_link('Your Home Project')
    end
    within('table#packages-table') do
      click_link('build')
    end
    click_link('Delete Package')
    expect(page).to have_content('Do you really want to delete this package?')
    click_button('Delete')
    expect(page).to have_content('Package was successfully removed.')
  end

  it 'is able to successfully build' do
    100.downto(1) do |counter|
      visit('/package/show/home:Admin/hello_world')
      # Force to wait for the build results ajax call. page.all doesn't wait for AJAX calls to finish
      sleep(5)
      puts "Refreshed build results, #{counter} retries left."
      builds_in_final_state = page.all('a', class: /build-state-(succeeded|failed)/).length
      break if builds_in_final_state.positive?
    end
    expect(page).to have_link('succeeded')
  end
end
