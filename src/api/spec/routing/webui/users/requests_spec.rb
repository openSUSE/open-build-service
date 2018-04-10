# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/users/:user/requests routes', type: :routing do
  let(:user) { Faker::Name.first_name }

  it do
    expect(get("/users/#{user}/requests"))
      .to route_to('webui/users/bs_requests#index', user: user)
  end
end
