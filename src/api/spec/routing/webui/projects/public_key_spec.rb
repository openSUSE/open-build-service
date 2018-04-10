# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ' projects/:project/public_key routes' do
  it do
    expect(get('/projects/TestProject/public_key'))
      .to route_to('webui/projects/public_key#show', project_name: 'TestProject')
  end
end
