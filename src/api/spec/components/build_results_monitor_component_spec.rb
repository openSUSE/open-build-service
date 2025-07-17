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

  it 'includes a RMP Lint badge on package pkg1' do
    render_inline(described_class.new(raw_data: raw_data, filter_url: filter_url, filters: []))

    expect(page).to have_css('#collapse-pkg1 .btn', text: 'RPM Lint')
  end

  context 'for multibuild package' do
    let(:project) { create(:project, name: 'prj') }
    let!(:multibuild_package) { create(:multibuild_package, name: 'multibuild_pkg', project: project, flavors: %w[foo bar]) }

    before do
      raw_data << { architecture: 'x86_64', repository: 'openSUSE_Tumbleweed', status: 'signing', package_name: 'multibuild_pkg', project_name: 'prj', repository_status: 'building' }
      # allow_any_instance_of(Package).to receive(:multibuild?).and_return(true)
    end

    it 'does not include a RMP Lint badge on multibuild packages' do
      pending 'Fix BuildResultsMonitorComponent#project_name and set up multibuild package correctly'

      render_inline(described_class.new(raw_data: raw_data, filter_url: filter_url, filters: []))

      expect(page).to have_css('#collapse-pkg2_foo')
      expect(page).not_to have_css('#collapse-pkg2_foo .btn', text: 'RPM Lint')
    end
  end
end
