RSpec.describe 'webui/request/_action_description.haml' do
  let(:release_project) { 'openSUSE:Backports:SLE-15-SP7:Update' }
  let(:action) do
    build(:bs_request_action_maintenance_incident,
          source_project: 'openSUSE:Factory', source_package: 'rclone',
          target_project: 'openSUSE:Maintenance', target_releaseproject: release_project)
  end

  before do
    render partial: 'webui/request/action_description', locals: { action: action }
  end

  it 'shows the final release destination of a maintenance incident' do
    expect(Nokogiri::HTML.fragment(rendered).text.squish).to include("(release in #{release_project})")
  end

  context 'without a release destination' do
    let(:release_project) { nil }

    it 'omits the release destination text' do
      expect(rendered).not_to include('release in')
    end
  end
end
