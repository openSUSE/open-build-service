require "spec_helper"
#for getting spec file
require 'tmpdir'
require "net/https"
require "uri"
require "nokogiri"

def get_build_source(download_url)
  text = Net::HTTP.get(URI.parse(download_url))

  xml_doc = Nokogiri::XML(text)

  stb = ''

  xml_doc.xpath("//directory/entry").each do |entry|

    return entry['name'] if /^obs-build.*\.tar\.gz$/.match(entry['name'])

  end
end


RSpec.describe "Preparation for building package obs-build" do


  it "should be able to login as user 'Admin'" do
    obs_login('Admin','opensuse')
    visit("/project/show/home:Admin")
  end

  it "should be able to create a new package 'build'" do
    find('img[title="Create package"]').click
    expect(page).to have_content("Create New Package for home:Admin")
    fill_in 'name', with: 'obs-build'
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Package 'obs-build' was created successfully")

  end

  # prepare for upload
  download_url = "https://api.opensuse.org/public/source/OBS:Server:2.7/build"
  dir = Dir.mktmpdir
  # get spec file
  upload_files = ['build.spec','_service']
  upload_files.push(get_build_source(download_url))
  upload_files.each do |fn|
    it "should be able to upload #{fn}" do
      File.write("#{dir}/#{fn}", Net::HTTP.get(URI.parse("#{download_url}/#{fn}")))
      find('img[title="Add file"]').click
      expect(page).to have_content("Add File to")
      attach_file("file", "#{dir}/#{fn}")
      find('input[name="commit"]').click #Save changes
      expect(page).to have_content("Source Files")
    end
  end

  it "should be able to add build targets from existing repos" do
    click_link('build targets')
    expect(page).to have_content("openSUSE distributions")
    check('repo_openSUSE_Tumbleweed')
    expect(page).to have_content("Successfully added repository 'openSUSE_Tumbleweed'")
    check('repo_openSUSE_Leap_42_1')
    expect(page).to have_content("Successfully added repository 'openSUSE_Leap_42.1'")
  end

  it "should be able to disable x86_64 in Tumbleweed" do
    visit("/project/repositories/home:Admin")
    edit_links = page.all(:link, text: "Edit repository")
    edit_links[1].click
    uncheck("arch_x86_64")
    click_button("Update openSUSE_Tumbleweed")
  end

end
