RSpec.describe ReconcileLinkedPackageJob, :vcr do
  let(:admin) { create(:admin_user, login: 'Admin') }
  let(:scmsync_project) { create(:project, name: 'scmsync_home', scmsync: 'https://example.com/repo.git') }
  let(:normal_project) { create(:project, name: 'normal_home') }
  let(:meta) do
    %(<package name="pkg" project="#{scmsync_project.name}"><title>Linked pkg</title><description>desc</description></package>)
  end

  before do
    admin
    allow(Backend::Api::Sources::Package).to receive(:meta).and_return(meta)
  end

  describe 'create/update' do
    it 'creates a LinkedPackage from the backend meta' do
      expect do
        described_class.perform_now(action: 'create', project_name: scmsync_project.name, package_name: 'pkg')
      end.to change { scmsync_project.linked_packages.count }.by(1)

      package = scmsync_project.linked_packages.find_by(name: 'pkg')
      expect(package).to have_attributes(type: 'LinkedPackage', title: 'Linked pkg', description: 'desc')
    end

    it 'updates an existing linked package instead of duplicating it' do
      create(:linked_package, name: 'pkg', project: scmsync_project, title: 'old')

      expect do
        described_class.perform_now(action: 'update', project_name: scmsync_project.name, package_name: 'pkg')
      end.not_to change(scmsync_project.linked_packages, :count)

      expect(scmsync_project.linked_packages.find_by(name: 'pkg').title).to eq('Linked pkg')
    end

    it 'strips the multibuild flavor suffix' do
      described_class.perform_now(action: 'create', project_name: scmsync_project.name, package_name: 'pkg:flavor')

      expect(scmsync_project.linked_packages.pluck(:name)).to contain_exactly('pkg')
    end

    it 'destroys a stale record when the backend meta is gone' do
      create(:linked_package, name: 'pkg', project: scmsync_project)
      allow(Backend::Api::Sources::Package).to receive(:meta).and_raise(Backend::NotFoundError)

      described_class.perform_now(action: 'create', project_name: scmsync_project.name, package_name: 'pkg')

      expect(scmsync_project.linked_packages.find_by(name: 'pkg')).to be_nil
    end
  end

  describe 'delete' do
    it 'destroys the linked package' do
      create(:linked_package, name: 'pkg', project: scmsync_project)

      expect do
        described_class.perform_now(action: 'delete', project_name: scmsync_project.name, package_name: 'pkg')
      end.to change { scmsync_project.linked_packages.count }.by(-1)
    end

    it 'is a no-op when the linked package does not exist' do
      expect do
        described_class.perform_now(action: 'delete', project_name: scmsync_project.name, package_name: 'missing')
      end.not_to raise_error
    end
  end

  describe 'guards' do
    it 'does nothing for a normal (frontend-managed) project' do
      expect do
        described_class.perform_now(action: 'create', project_name: normal_project.name, package_name: 'pkg')
      end.not_to change(LinkedPackage, :count)
    end

    it 'does nothing for an unknown project' do
      expect do
        described_class.perform_now(action: 'create', project_name: 'does:not:exist', package_name: 'pkg')
      end.not_to change(LinkedPackage, :count)
    end

    # The discriminator is project.maintained_by_backend?, not scmsync specifically, so remote
    # packages are reconciled automatically if the backend ever emits events for them.
    it 'reconciles packages of a remote instance project' do
      remote_project = create(:project, name: 'remote_home', remoteurl: 'https://api.example.com/public')

      expect do
        described_class.perform_now(action: 'create', project_name: remote_project.name, package_name: 'pkg')
      end.to change { remote_project.linked_packages.count }.by(1)
    end
  end
end
