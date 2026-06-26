RSpec.describe BuildResultsMonitorComponent, type: :component do
  subject(:component) { described_class.new(raw_data: raw_data, filter_url: filter_url, filters: filters) }

  let(:raw_data) do
    [
      { architecture: 'i586', repository: 'Debian_12', status: 'excluded', package_name: 'pkg1', project_name: 'prj', repository_status: 'unpublished' },
      { architecture: 'x86_64', repository: 'openSUSE_Tumbleweed', status: 'signing', package_name: 'pkg1', project_name: 'prj', repository_status: 'building' },
      { architecture: 'i586', repository: '15.6', status: 'signing', package_name: 'pkg1', project_name: 'prj', repository_status: 'building' },
      { architecture: 'i586', repository: 'Debian_11', status: 'failed', package_name: 'pkg1', project_name: 'prj', repository_status: 'failed' }
    ]
  end

  let(:filter_url) { '/requests/10/build_results' }
  let(:filters) { %w[status_succeeded status_failed status_unresolvable status_scheduled status_building status_signing] }

  # rubocop:disable RSpec/MultipleExpectations
  it 'renders only results that match the allowed status filters' do
    render_inline(described_class.new(raw_data: raw_data, filter_url: filter_url, filters: filters))

    expect(page).to have_text('pkg1')
    expect(page).to have_link('openSUSE_Tumbleweed')
    expect(page).to have_css('.build-result-architecture', text: 'Signing', count: 2)
    expect(page).to have_css('.build-result-architecture', text: 'x86_64')
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'does not render results with excluded filters' do
    render_inline(described_class.new(raw_data: raw_data, filter_url: filter_url, filters: ['status_failed']))

    expect(page).to have_text('Failed')
    expect(page).to have_no_link('openSUSE_Tumbleweed')
  end
end
