RSpec.describe BranchPackage::CheckForUpdate, :vcr do
  subject { check_for_update }

  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_project) { user.home_project }
  let!(:project) { create(:project, name: 'BaseDistro') }
  let!(:package) { create(:package, name: 'test_package', project: project) }
  let!(:update_project) { create(:project, name: 'BaseDistro:Update') }
  let!(:update_package) { create(:package, name: 'test_package', project: update_project) }
  let(:update_project_attrib) { create(:update_project_attrib, project: project, update_project: update_project) }

  let(:update_attribute_namespace) { 'OBS' }
  let(:update_attribute_name) { 'UpdateProject' }

  let(:package_hash) { { package: package, link_target_project: update_project } }

  let(:check_for_update) do
    described_class.new(package_hash: package_hash,
                        update_attribute_namespace: update_attribute_namespace,
                        update_attribute_name: update_attribute_name,
                        extend_names: true, copy_from_devel: false, params: {})
  end

  before do
    login user
    update_project_attrib
  end

  it { expect(subject).not_to be_nil }
  it { expect { subject.check_for_update_project }.not_to raise_error }
  it { expect(subject.package_hash).not_to be_nil }
end
