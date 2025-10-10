RSpec.describe PackageVersionUpstream do
  subject { described_class.new(version: '2.1.0', package: package) }

  let(:project) { create(:project_with_package, name: 'factory', package_name: 'hello') }
  let(:package) { project.packages.first }
  let!(:package_version_local) { create(:package_version_local, version: '2.0.0', package: package) }

  describe '#save' do
    context 'when the local package version is older then the upstream one' do
      let!(:package_version_local) { create(:package_version_local, version: '2.0.0', package: package) }

      it 'creates a PackageOutOfDate event' do
        expect { subject.save }.to change(Event::PackageOutOfDate, :count).from(0).to(1)
        expect(Event::PackageOutOfDate.first).to have_attributes(payload: { 'local_version' => package_version_local.version, 'upstream_version' => '2.1.0', 'project' => project.name,
                                                                            'package' => package.name })
      end
    end

    context 'when the local package version is equal to the upstream one' do
      let!(:package_version_local) { create(:package_version_local, version: '2.1.0', package: package) }

      it 'does not create a PackageOutOfDate event' do
        expect { subject.save }.not_to change(Event::PackageOutOfDate, :count)
      end
    end
  end
end
