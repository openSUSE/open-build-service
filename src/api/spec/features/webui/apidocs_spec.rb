require 'browser_helper'

RSpec.feature 'Apidocs', type: :feature do
  scenario 'main page' do
    visit '/apidocs/'

    expect(page.body).to have_title('Open Build Service')
  end

  scenario 'main page with example link' do # /apidocs/about.xml
    visit '/apidocs/'
    click_link('Example', match: :first)

    expect(page.response_headers['Content-Type']).to eq "text/xml"
    expect(page.body).to have_title('Open Build Service API')
  end

  scenario 'main page with existing sub page' do
    visit '/apidocs/'
    find(:xpath, '//a[@href="architecture.xml"]').click

    expect(page.response_headers['Content-Type']).to eq "text/xml"
    expect(page.body).to match(/architecture name="x86_64/)
  end
end
