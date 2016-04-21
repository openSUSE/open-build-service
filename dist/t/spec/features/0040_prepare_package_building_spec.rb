require "spec_helper"
#for getting spec file
require 'tmpdir'
require "net/https"
require "uri"

RSpec.describe "Preparation for building package obs-build" do


  it "should be able to login as user 'Admin'" do
    obs_login('Admin','opensuse')
    visit("/project/show/home:Admin")
  end

  it "should be able to create a new package from OBS:Server:Unstable/build/build.spec and _service files" do
    dir = Dir.mktmpdir
    File.write("#{dir}/build.spec", Net::HTTP.get(URI.parse("https://api.opensuse.org/public/source/OBS:Server:Unstable/build/build.spec")))
    find('img[title="Create package"]').click
    expect(page).to have_content("Create New Package for home:Admin")
    fill_in 'name', with: 'obs-build'
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Package 'obs-build' was created successfully")
    find('img[title="Add file"]').click
    expect(page).to have_content("Add File to")
    attach_file("file", "#{dir}/build.spec")
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Source Files")
    File.write("#{dir}/_service", Net::HTTP.get(URI.parse("https://api.opensuse.org/public/source/OBS:Server:Unstable/build/_service")))
    find('img[title="Add file"]').click
    expect(page).to have_content("Add File to")
    attach_file("file", "#{dir}/_service")
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Source Files")
  end

  it "should be able to add build targets from existing repos" do
    click_link('build targets')
    expect(page).to have_content("openSUSE distributions")
    check('repo_openSUSE_Tumbleweed')
    check('repo_openSUSE_Leap_42.1')
    find('input[id="submitrepos"]').click #Add selected repositories
    expect(page).to have_content("Successfully added repositories")
    expect(page).to have_content("openSUSE_Leap_42.1 (x86_64)")
    expect(page).to have_content("openSUSE_Tumbleweed (i586, x86_64)")
  end

  it "should be able to disable x86_64 in Tumbleweed" do
    visit("/project/repositories/home:Admin")
    edit_links = page.all(:link, text: "Edit repository")
    edit_links[1].click
    uncheck("arch_x86_64")
    click_button("Update openSUSE_Tumbleweed")
  end

  it "should be able to add a DOD repository for Leap (x86_64)" do
    visit("/project/repositories/home:Admin")
    find_by_id("add_dod_repository_link_openSUSE_Leap_42_1").click
    first(:xpath,'//*[@id="download_repository_url"]').set "http://download.opensuse.org/repositories/openSUSE:/Tools/openSUSE_42.1/"
    find("input#add_dod_button").click
  end

  it "should be able to add a DOD repository for Tumbleweed (i586)" do
    visit("/project/repositories/home:Admin")
    find_by_id("add_dod_repository_link_openSUSE_Tumbleweed").click
    first(:xpath,'//*[@id="download_repository_url"]').set "http://download.opensuse.org/repositories/openSUSE:/Tools/openSUSE_42.1/"
    find("input#add_dod_button").click
  end


end
