module RedirectBack
  # Usage in specs:
  #
  #  describe 'POST #create' do
  #    it 'redirects back' do
  #      from about_path
  #      post :create, params: { thing: @thing }
  #      expect(response).to redirect_to about_url
  #    end
  #  end
  def from(url)
    request.env['HTTP_REFERER'] = url
  end
end

RSpec.configure do |config|
  config.include RedirectBack
end
