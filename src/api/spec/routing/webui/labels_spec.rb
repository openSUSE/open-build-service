RSpec.describe '/labels routes' do
  it 'routes GET /labels/autocomplete to webui/labels#autocomplete with autocomplete_labels_path helper' do
    expect(get('/labels/autocomplete')).to route_to(controller: 'webui/labels', action: 'autocomplete')
    expect(autocomplete_labels_path).to eq('/labels/autocomplete')
  end
end
