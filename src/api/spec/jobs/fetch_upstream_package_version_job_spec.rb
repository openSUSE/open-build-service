RSpec.describe FetchUpstreamPackageVersionJob, :vcr do
  describe '#perform' do
    let!(:project) { create(:project_with_package, name: 'factory', package_name: 'hello', anitya_distribution_name: 'openSUSE') }
    let(:package) { project.packages.first }

    context 'providing a project name' do
      before do
        described_class.perform_now(project_name: project.name)
      end

      it 'creates a package version upstream record for the projects packages' do
        expect(PackageVersionUpstream.count).to eq(1)
        expect(package.package_versions.first).to have_attributes(version: '2.12.2', type: 'PackageVersionUpstream')
      end
    end

    context 'not providing a project name' do
      let!(:another_project) { create(:project_with_package, name: 'games', package_name: '0ad', anitya_distribution_name: 'openSUSE') }
      let(:another_package) { another_project.packages.first }

      before do
        described_class.perform_now
      end

      it 'creates a package version upstream record for all projects packages with the attribute assigned' do
        expect(PackageVersionUpstream.all).to contain_exactly(have_attributes(version: '0.27.1', type: 'PackageVersionUpstream'), have_attributes(version: '2.12.2', type: 'PackageVersionUpstream'))
      end
    end
  end
end
