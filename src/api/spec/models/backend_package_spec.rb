RSpec.describe BackendPackage, :vcr do
  describe '.refresh_dirty' do
    subject { BackendPackage.refresh_dirty }

    let!(:project) { create(:project, name: 'apache') }
    let!(:package) { create(:package_with_file, project: project, name: 'mod_ssl') }

    it do
      expect { subject }.to change(BackendPackage, :count).by(1)
    end
  end
end
