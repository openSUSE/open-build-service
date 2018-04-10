# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'WebuiMatcher' do
  it 'routes html format request to Webui controllers' do
    expect(get('/')).to route_to('webui/main#index')
  end

  it 'monitor in xml format should not be routable' do
    expect(get('/monitor.xml')).not_to be_routable
  end
end
