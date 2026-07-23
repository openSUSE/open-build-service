RSpec.describe LinkedPackage, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_project) { user.home_project }
  let(:scmsync_project) { create(:project, name: 'scmsync_home', scmsync: 'https://example.com/repo.git') }
  let!(:normal_package) { create(:package, name: 'normal', project: home_project) }
  let!(:linked_package) { create(:linked_package, name: 'linked', project: scmsync_project) }

  before do
    login(user)
  end

  describe 'STI type' do
    it 'stores the class name in the type column' do
      expect(linked_package.type).to eq('LinkedPackage')
    end

    it 'leaves the type NULL for a normal package' do
      expect(normal_package.type).to be_nil
    end
  end

  describe 'default scope' do
    it 'excludes linked packages from the Package scope' do
      expect(Package.all).not_to include(linked_package)
      expect(Package.all).to include(normal_package)
    end

    it 'only returns linked packages from the LinkedPackage scope' do
      expect(LinkedPackage.all).to contain_exactly(linked_package)
    end

    it 'filters the base scope by NULL type' do
      expect(Package.all.to_sql).to include('`packages`.`type` IS NULL')
    end

    it 'filters the subclass scope by its type and not by NULL type' do
      expect(LinkedPackage.all.to_sql).to include("`packages`.`type` = 'LinkedPackage'")
      expect(LinkedPackage.all.to_sql).not_to include('IS NULL')
    end

    it 'raises RecordNotFound when looking a linked package up via the base class' do
      expect { Package.find(linked_package.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    # Guards the `Package.unscoped` used to build the forbidden subquery: otherwise a forbidden
    # linked package would leak into LinkedPackage.all.
    it 'excludes forbidden linked packages from the LinkedPackage scope' do
      forbidden_project = create(:forbidden_project, name: 'forbidden_scmsync', scmsync: 'https://example.com/secret.git')
      # A project is only forbidden to others once it has a maintainer whitelist that excludes them.
      create(:relationship_project_user, project: forbidden_project, user: create(:confirmed_user))
      forbidden = create(:linked_package, name: 'secret', project: forbidden_project)
      # forbidden_project_ids is cached; discard it so the freshly forbidden project is recomputed.
      Relationship.discard_cache

      expect(LinkedPackage.all).not_to include(forbidden)
    end
  end

  describe 'project associations' do
    it 'excludes linked packages from Project#packages' do
      expect(scmsync_project.packages).not_to include(linked_package)
    end

    it 'exposes linked packages via Project#linked_packages' do
      expect(scmsync_project.linked_packages).to contain_exactly(linked_package)
    end
  end

  describe '#backend_writable?' do
    it 'is false for a linked package' do
      expect(linked_package.backend_writable?).to be(false)
    end

    it 'is true for a normal package' do
      expect(normal_package.backend_writable?).to be(true)
    end
  end

  describe 'backend write guard' do
    context 'with global_write_through enabled' do
      before { allow(CONFIG).to receive(:[]).and_call_original }

      it 'refuses to write a linked package meta to the backend' do
        allow(CONFIG).to receive(:[]).with('global_write_through').and_return(true)
        linked_package.title = 'changed'

        expect { linked_package.save! }.to raise_error(Package::Errors::LinkedPackageReadOnly)
      end

      it 'allows the reconcile path (no_backend_write) to save' do
        allow(CONFIG).to receive(:[]).with('global_write_through').and_return(true)
        linked_package.title = 'changed'
        linked_package.commit_opts = { no_backend_write: 1 }

        expect { linked_package.save! }.not_to raise_error
      end
    end
  end

  describe '.get_by_project_and_name' do
    context 'with the linked_packages beta feature enabled' do
      before { Flipper.enable(:linked_packages, user) }

      it 'returns the persisted linked package for a scmsync project' do
        found = described_class.get_by_project_and_name(scmsync_project.name, linked_package.name,
                                                        use_source: false, follow_project_scmsync_links: true)
        expect(found).to eq(linked_package)
      end

      it 'raises UnknownObjectError for a missing scmsync package' do
        expect do
          described_class.get_by_project_and_name(scmsync_project.name, 'does_not_exist',
                                                  use_source: false, follow_project_scmsync_links: true)
        end.to raise_error(Package::Errors::UnknownObjectError)
      end
    end

    context 'without the linked_packages beta feature' do
      before do
        allow(Backend::Api::Sources::Package).to receive(:meta)
          .and_return(%(<package name="#{linked_package.name}" project="#{scmsync_project.name}"><title>ephemeral</title></package>))
      end

      it 'falls back to a readonly package built from the backend meta' do
        found = described_class.get_by_project_and_name(scmsync_project.name, linked_package.name,
                                                        use_source: false, follow_project_scmsync_links: true)
        expect(found).to be_readonly
        expect(found).not_to eq(linked_package)
      end
    end
  end
end
