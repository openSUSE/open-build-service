RSpec.describe PackageVersionUpstream do
  let(:project) { create(:project_with_package, name: 'factory', package_name: 'hello') }
  let(:package) { project.packages.first }
  let(:package_version_upstream) { create(:package_version_upstream, package: package) }

  describe '#create' do
    it 'creates an event' do
      expect { package_version_upstream }.to change(Event::UpstreamPackageVersionChanged, :count).from(0).to(1)
      expect(Event::UpstreamPackageVersionChanged.first).to have_attributes(payload: { 'project' => project.name, 'package' => package.name,
                                                                                       'upstream_version' => package_version_upstream.version })
    end
  end
end
