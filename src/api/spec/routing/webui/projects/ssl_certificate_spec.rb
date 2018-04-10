# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ' projects/:project/ssl_certificate routes' do
  it do
    expect(get('/projects/TestProject/ssl_certificate'))
      .to route_to('webui/projects/ssl_certificate#show', project_name: 'TestProject')
  end
end
