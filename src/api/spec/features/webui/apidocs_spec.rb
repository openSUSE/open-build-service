require 'browser_helper'

RSpec.describe 'Apidocs', type: :feature, js: true do
  let(:user) { create(:confirmed_user) }
  let(:tmp_dir) { Dir.mktmpdir }
  let(:tmp_file) { "#{tmp_dir}/index.html" }

  before do
    login user
    File.open(tmp_file, 'w') do |f|
      f.write('<html><head></head><body><h1>API Documentation</h1></body></html>')
    end
    CONFIG['apidocs_location'] = tmp_dir
    visit apidocs_index_path
  end

  after do
    File.delete(tmp_file)
    Dir.rmdir(tmp_dir)
  end

  it 'is wrapped by a Bootstrap class' do
    expect(page).to have_css('#content > .card')
  end

  it 'includes the file content' do
    expect(page).to have_content('API Documentation')
  end
end
