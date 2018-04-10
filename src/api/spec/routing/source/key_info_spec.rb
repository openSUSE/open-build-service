# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ' source/:project/_keyinfo routes' do
  it do
    expect(get('/source/TestProject/_keyinfo.xml'))
      .to route_to('source/key_info#show', project: 'TestProject', format: 'xml')
  end
end
