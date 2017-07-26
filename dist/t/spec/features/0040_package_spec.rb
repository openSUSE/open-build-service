require "spec_helper"

RSpec.describe "Package" do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it "should be able to create new" do
    within("div#subheader") do
      click_link('Home Project')
    end
    click_link('Create package')
    fill_in 'name', with: 'ctris'
    fill_in 'title', with: 'ctris'
    fill_in 'description', with: 'ctris'
    click_button('Save changes')
    expect(page).to have_content("Package 'ctris' was created successfully")
  end

  it "should be able to upload files" do
    within("div#subheader") do
      click_link('Home Project')
    end
    click_link('ctris')
    click_link('Add file')
    attach_file("file", File.expand_path('../../fixtures/ctris.spec', __FILE__))
    click_button('Save changes')
    expect(page).to have_content("The file 'ctris.spec' has been successfully saved.")

    # second line of defense ;-)
    click_link('Add file')
    attach_file("file", File.expand_path('../../fixtures/ctris-0.42.tar.bz2', __FILE__))
    click_button('Save changes')
    expect(page).to have_content("The file 'ctris-0.42.tar.bz2' has been successfully saved.")
  end

  it "should be able to branch" do
    within("div#subheader") do
      click_link('Home Project')
    end
    click_link('Branch existing package')
    fill_in 'linked_project', with: 'openSUSE.org:openSUSE:Tools'
    fill_in 'linked_package', with: 'build'
    # Do not wait for autocomplete
    page.execute_script("$('input[type=\"submit\"]').prop('disabled', false)")
    click_button('Create Branch')
    expect(page).to have_content('Successfully branched package')
  end

  it 'should be able to delete' do
    click_link('Delete package')
    expect(page).to have_content('Do you really want to delete this package?')
    click_button('Ok')
    expect(page).to have_content('Package was successfully removed.')
  end

  it "should be able to successfully build" do
    100.downto(1) do |counter|
      visit("/package/show/home:Admin/ctris")
      # wait for the build results ajax call
      sleep(5)
      puts "Refreshed build results, #{counter} retries left."
      succeed_build = page.all('td', class: 'status_succeeded')
      if succeed_build.length == 1
        break
      end
    end
  end
end
