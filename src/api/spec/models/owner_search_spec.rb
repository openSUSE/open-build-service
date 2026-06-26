RSpec.describe OwnerSearch do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let!(:develuser) { create(:confirmed_user, :with_home, login: 'DevelIggy') }
  let!(:package) { create(:package, name: 'TestPack', project: Project.find_by(name: 'home:Iggy')) }
  let!(:develpackage) { create(:package, name: 'DevelPack', project: Project.find_by(name: 'home:DevelIggy')) }
  let!(:collection) do
    file_fixture('owner_search_collection.xml').read
  end
  let!(:maintenance_collection) do
    file_fixture('owner_search_maintenance_collection.xml').read
  end

  before do
    login user
    create(:attrib, attrib_type: AttribType.where(name: 'OwnerRootProject').first, project: Project.find_by(name: 'home:Iggy'))
  end

  describe '#search' do
    context 'in normal projects' do
      before do
        allow(Backend::Api::Search).to receive(:binary).and_return(collection)
      end

      it 'returns results' do
        subject = OwnerSearch::Container.new.for(package).first
        expect(subject.users).to eq('maintainer' => [user])
      end

      # the User.owner is only interesting for locked accounts
      it 'does not respect User.owner' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update(owner: develuser)

        subject = OwnerSearch::Container.new(devel: false, filter: 'bugowner').for(package).first
        expect(subject.users['bugowner']).to eq([user])
      end

      it 'respects User.state' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update(state: :locked)

        subject = OwnerSearch::Container.new(devel: false, filter: 'bugowner').for(package)
        expect(subject).to eq([])
      end
    end

    describe '#missing' do
      it 'returns nothing for default filter' do
        subject = OwnerSearch::Missing.new.find
        expect(subject).to be_empty
      end

      it 'returns results for packages without bugowner' do
        subject = OwnerSearch::Missing.new(devel: false, filter: 'bugowner').find.first
        expect(subject.rootproject).to eq('home:Iggy')
        expect(subject.project).to eq('home:Iggy')
        expect(subject.package).to eq('TestPack')
      end

      it 'returns nothing for packages with bugowner' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))

        subject = OwnerSearch::Missing.new(devel: false, filter: 'bugowner').find
        expect(subject).to eq([])
      end

      it 'respects User.state' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update(state: :locked)

        subject = OwnerSearch::Missing.new(devel: false, filter: 'bugowner').find.first
        expect(subject.rootproject).to eq('home:Iggy')
        expect(subject.project).to eq('home:Iggy')
        expect(subject.package).to eq('TestPack')
        expect(subject.users).to be_nil
      end

      it 'respects User.owner' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update(owner: develuser)

        subject = OwnerSearch::Missing.new(devel: false, filter: 'bugowner').find
        expect(subject).to eq([])

        develuser.update(state: :locked)

        subject = OwnerSearch::Missing.new(devel: false, filter: 'bugowner').find.first
        expect(subject.rootproject).to eq('home:Iggy')
        expect(subject.project).to eq('home:Iggy')
        expect(subject.package).to eq('TestPack')
      end
    end

    context 'in maintenance projects' do
      let(:project) { Project.find_by(name: 'home:Iggy') }
      let!(:project_kind) { project.update(kind: 'maintenance_release') }
      let(:other_user) { create(:confirmed_user, login: 'hans') }

      # A package with bugowner develuser
      let(:package42) { create(:package, name: 'package.42', project: project) }
      # FIXME: bugowner should be a transitive argument to the package factory
      let!(:bugowner) { create(:relationship_package_user_as_bugowner, user: develuser, package: package42) }

      # A local link to package.42 with bugowner other_user
      let(:package) { create(:package, name: 'package', project: project) }
      # FIXME: package link should be a transitive argument to the package factory
      let!(:package_link) { package.build_backend_package.update(links_to_id: package42) }
      let!(:other_bugowner) { create(:relationship_package_user_as_bugowner, user: other_user, package: package) }

      # A patchinfo with bugowner maintenance_user
      let(:patchinfo42) { create(:package, name: 'patchinfo.42', project: project) }
      # FIXME: package kind should be a transitive argument to the package factory
      let!(:kind_patchinfo) { PackageKind.create(package_id: patchinfo42.id, kind: 'patchinfo') }
      let(:maintenance_user) { create(:confirmed_user, login: 'MaintenanceIggy') }
      # FIXME: bugowner should be a transitive argument to the package factory
      let!(:maintenance_bugowner) { create(:relationship_package_user_as_bugowner, user: maintenance_user, package: patchinfo42) }

      before do
        allow(Backend::Api::Search).to receive(:binary).and_return(maintenance_collection)
      end

      it 'respects maintenance project suffixes' do
        expect(OwnerSearch::Assignee.new.for('package').first.users).to eq('bugowner' => [other_user])
        expect(OwnerSearch::Assignee.new.for('package_42').first.users).to eq('bugowner' => [other_user])
        expect(OwnerSearch::Assignee.new.for('patchinfo_42').first.users).to eq('bugowner' => [other_user])
      end

      context 'with owned user' do
        let(:owning) { create(:confirmed_user) }

        before do
          other_user.update(owner: owning, state: :subaccount)
        end

        it 'still returns the owned user as bugowner' do
          expect(OwnerSearch::Assignee.new(filter: 'bugowner').for('package').first.users).to eq('bugowner' => [other_user])
          expect(OwnerSearch::Assignee.new(filter: 'bugowner').for('package_42').first.users).to eq('bugowner' => [other_user])
          expect(OwnerSearch::Assignee.new(filter: 'bugowner').for('patchinfo_42').first.users).to eq('bugowner' => [other_user])
        end

        context 'with gone owner' do
          let(:owning) { create(:locked_user) }

          it 'does not return bugowners' do
            expect(OwnerSearch::Assignee.new(filter: 'bugowner').for('package')).to be_empty
          end
        end
      end
    end
  end
end
