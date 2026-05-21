RSpec.describe '/my/requests routes' do
  it do
    expect(get('/my/requests'))
      .to route_to('webui/users/bs_requests#index')
  end
end
