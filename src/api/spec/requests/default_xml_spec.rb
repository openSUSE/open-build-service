require 'rails_helper'

RSpec.describe 'All requests' do
  it 'prefers XML over HTML' do
    get '/search/request', headers: { 'ACCEPT' => nil }

    expect(response.content_type).to eq('application/xml; charset=utf-8')
  end
end
