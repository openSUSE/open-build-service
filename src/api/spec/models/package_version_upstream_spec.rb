RSpec.describe PackageVersionUpstream do
  subject { described_class.new(version: '2.1.0', package: package) }

  let(:project) { create(:project_with_package, name: 'factory', package_name: 'hello') }
  let(:package) { project.packages.first }
  let!(:package_version_local) { create(:package_version_local, package: package) }

  describe '#create' do
    it 'creates a PackageUpstreamVersionSourceChanged event' do
      expect { subject.save }.to change(Event::PackageUpstreamVersionSourceChanged, :count).from(0).to(1)
      expect(Event::PackageUpstreamVersionSourceChanged.first).to have_attributes(payload: { 'local_version' => package_version_local.version, 'upstream_version' => '2.1.0', 'project' => project.name,
                                                                                             'package' => package.name })
    end
  end
end
