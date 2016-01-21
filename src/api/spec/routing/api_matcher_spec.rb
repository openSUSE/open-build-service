require 'rails_helper'

RSpec.describe 'APIMatcher' do
  it 'routes xml format request to API controllers' do
    expect(get('/distributions.xml')).to route_to(controller: 'distributions', action: 'index', format: 'xml')
  end

  it 'distributions in html format should not be routable' do
    expect(get('/distributions')).not_to be_routable
  end
end
