RSpec.describe ReconcileLinkedPackageCallback, :vcr do
  let!(:scmsync_project) { create(:project, name: 'scmsync_home', scmsync: 'https://example.com/repo.git') }
  let(:payload) { { 'project' => scmsync_project.name, 'package' => 'pkg', 'sender' => 'Admin' } }

  before do
    allow(ReconcileLinkedPackageJob).to receive(:perform_later)
  end

  shared_examples 'an upsert-reconciling event' do |event_class|
    it "enqueues a create reconcile job for #{event_class}" do
      event_class.create(payload)

      expect(ReconcileLinkedPackageJob).to have_received(:perform_later)
        .with(action: 'create', project_name: scmsync_project.name, package_name: 'pkg')
    end
  end

  it_behaves_like 'an upsert-reconciling event', Event::CreatePackage
  it_behaves_like 'an upsert-reconciling event', Event::UpdatePackage
  it_behaves_like 'an upsert-reconciling event', Event::UndeletePackage

  it 'enqueues a delete reconcile job for Event::DeletePackage' do
    Event::DeletePackage.create(payload)

    expect(ReconcileLinkedPackageJob).to have_received(:perform_later)
      .with(action: 'delete', project_name: scmsync_project.name, package_name: 'pkg')
  end

  it 'does not enqueue a job for a normal (frontend-managed) project' do
    normal_project = create(:project, name: 'normal_home')

    Event::CreatePackage.create(payload.merge('project' => normal_project.name))

    expect(ReconcileLinkedPackageJob).not_to have_received(:perform_later)
  end
end
