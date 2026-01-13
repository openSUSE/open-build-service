RSpec.describe ChartComponent, type: :component do
  subject { described_class.new(raw_data: fake_raw_data) }

  let(:fake_raw_data) do
    [
      { architecture: 'x86_64', repository: 'openSUSE_Leap_42.2', status: 'excluded', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 'i586', repository: 'openSUSE_Tumbleweed', status: 'unresolvable', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 's390', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 'x86_64', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 's390', repository: 'openSUSE_Tumbleweed', status: 'building', package_name: 'source_package', project_name: 'source_project' }
    ]
  end

  describe '#chart_data' do
    let(:chart_data) { subject.chart_data }

    it { expect(chart_data.size).to eq(3) }
    it { expect(chart_data.pluck(:name)).to include('Published') }
    it { expect(chart_data.pluck(:data)).to include({ 'Debian_Stable' => 2 }) }
  end

  describe '#distinct_repositories' do
    let(:distinct_repositories) { subject.distinct_repositories }

    it { expect(distinct_repositories).to include('openSUSE_Tumbleweed') }
    it { expect(distinct_repositories).not_to include('openSUSE_Leap_42.2') }
    it { expect(distinct_repositories).not_to include('Debian_Unstable') }
  end

  context 'for build results with multibuild flavors' do
    let(:fake_raw_data) do
      [
        { architecture: 'x86_64', repository: 'openSUSE_Tumbleweed', status: 'succeeded', package_name: 'hello', project_name: 'home:Admin', repository_status: 'published', is_repository_in_db: true, details: nil,
          buildtype: 'spec' },
        { architecture: 'x86_64', repository: 'openSUSE_Tumbleweed', status: 'succeeded', package_name: 'hello:foo', project_name: 'home:Admin', repository_status: 'published', is_repository_in_db: true, details: nil,
          buildtype: 'spec' }
      ]
    end

    before do
      render_inline(subject)
    end

    it 'renders the build results summary for the individual multibuild flavors' do
      expect(rendered_content).to have_css('h5', text: 'hello')
      expect(rendered_content).to have_css('h5', text: 'hello:foo')
    end
  end
end
