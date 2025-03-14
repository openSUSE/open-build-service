require "spec_helper"

RSpec.describe "Package" do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it "should be able to create new" do
    within("div#personal-navigation") do
      click_link('Home Project')
    end
    click_link('Create Package')
    fill_in 'name', with: 'hello_world'
    fill_in 'title', with: 'hello_world'
    fill_in 'description', with: 'hello_world'
    click_button('Create')
    expect(page).to have_content("Package 'hello_world' was created successfully")
  end

  it "should be able to upload files" do
    within("div#personal-navigation") do
      click_link('Home Project')
    end
    click_link('hello_world')
    click_link('Add file')
    attach_file("file", File.expand_path('../fixtures/hello_world.spec', __dir__), make_visible: true)
    click_button('Save')
    expect(page).to have_content("The file 'hello_world.spec' has been successfully saved.")
  end

  it "should be able to branch" do
    within("div#personal-navigation") do
      click_link('Home Project')
    end
    click_link('Branch Existing Package')
    within('#new-package-branch-modal') do
      fill_in 'linked_project', with: 'openSUSE.org:openSUSE:Tools'
      fill_in 'linked_package', with: 'build'
      click_button('Accept')
    end
    expect(page).to have_content('build.spec')
  end

  it 'should be able to delete' do
    within("div#personal-navigation") do
      click_link('Home Project')
    end
    within("table#packages-table") do
      click_link('build')
    end
    click_link('Delete package')
    expect(page).to have_content('Do you really want to delete this package?')
    click_button('Delete')
    expect(page).to have_content('Package was successfully removed.')
  end

  it "should be able to successfully build" do
    100.downto(1) do |counter|
      visit("/package/show/home:Admin/hello_world")
      # wait for the build results ajax call
      sleep(5)
      puts "Refreshed build results, #{counter} retries left."
      succeed_build = page.all('a', class: 'build-state-succeeded')
      if succeed_build.length == 1
        break
      end
    end
  end
end
