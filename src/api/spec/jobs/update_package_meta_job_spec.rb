RSpec.describe UpdatePackageMetaJob, :vcr do
  include ActiveJob::TestHelper

  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }
  let(:package1) { create(:package, name: 'package_1', project: project) }
  let(:package2) { create(:package, name: 'package_2', project: project) }
  let!(:branch_package) { create(:branch_package_base, project: project.name, package: package1.name) }

  it 'is in default queue' do
    expect(UpdatePackageMetaJob.new.queue_name).to eq('default')
  end

  describe '#perform', skip: 'False positives. It is not testing what it should' do
    let!(:backend_package) { BackendPackage.create(package_id: package2.id) }
    let!(:kind_patchinfo) { PackageKind.create(package_id: package2.id, kind: 'patchinfo') }

    before do
      User.session = user
      branch_package.branch
      Package.last.update_backendinfo
    end

    it 'removes BackendPackage with links_to_ids is nil and package_kind is patchinfo' do
      expect { UpdatePackageMetaJob.new.perform }.to change(BackendPackage, :count).by(-1)
    end
  end

  describe '#scan_links', skip: 'False positives. It is not testing what it should' do
    # If the package has a link it will check if a BackendPackage exists, otherwise, it will create it.
    subject { UpdatePackageMetaJob.new.scan_links }

    before do
      User.session = user
      branch_package.branch
    end

    context 'with a BranchPackage that does have an entry in BackendPackage' do
      before do
        # It's needed to create a BackendPackage entry
        Package.last.update_backendinfo
      end

      it { expect { subject }.not_to change(BackendPackage, :count) }
    end

    context "with a BranchPackage that doesn't have an entry in BackendPackage" do
      it { expect { subject }.to change(BackendPackage, :count).by(1) }
    end
  end
end
