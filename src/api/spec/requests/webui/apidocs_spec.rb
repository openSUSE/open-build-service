RSpec.describe 'Apidocs' do
  it 'Redirects /apidocs-old to /apidocs-old/index' do
    get '/apidocs-old'
    expect(response).to redirect_to(apidocs_index_path)
  end
end
