require 'spec_helper'

RSpec.describe SyncLocalPackageVersionJob do
  describe '#create_package_version_local' do
    let(:xml) do
      <<~XML
        <sourceinfo package='pkg'>
          <version>2.0</version>
        </sourceinfo>
      XML
    end
    let(:package) { instance_double(Package, id: 1) }
    let(:package_version_local) { instance_double(PackageVersionLocal, persisted?: true) }
    let(:job) { described_class.new }

    before do
      allow(Backend::Api::Sources::Package).to receive(:files).and_return(xml)
      allow(Package).to receive(:find_by_project_and_name).and_return(package)
      allow(PackageVersionLocal).to receive(:find_or_create_by).and_return(package_version_local)
      allow(package_version_local).to receive(:touch)
      allow(job).to receive(:update_package_version_labels)
    end

    it 'requests expanded package info when fetching version' do
      job.send(:create_package_version_local, project_name: 'proj', package_name: 'pkg')

      expect(Backend::Api::Sources::Package).to have_received(:files)
        .with('proj', 'pkg', view: :info, parse: 1, expand: 1)
    end

    it 'creates a package version local record' do
      job.send(:create_package_version_local, project_name: 'proj', package_name: 'pkg')

      expect(PackageVersionLocal).to have_received(:find_or_create_by).with(version: '2.0', package: package)
    end
  end
end
