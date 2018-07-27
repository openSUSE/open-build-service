require 'rails_helper'

RSpec.describe OwnerSearch do
  let!(:user) { create(:confirmed_user, login: 'Iggy') }
  let!(:develuser) { create(:confirmed_user, login: 'DevelIggy') }
  let!(:owner_attrib) { create(:attrib, attrib_type: AttribType.where(name: 'OwnerRootProject').first, project: Project.find_by(name: 'home:Iggy')) }
  let!(:package) { create(:package, name: 'TestPack', project: Project.find_by(name: 'home:Iggy')) }
  let!(:develpackage) { create(:package, name: 'DevelPack', project: Project.find_by(name: 'home:DevelIggy')) }
  let!(:collection) do
    file_fixture('owner_search_collection.xml').read
  end
  let!(:maintenance_collection) do
    file_fixture('owner_search_maintenance_collection.xml').read
  end

  describe '#search' do
    context 'in normal projects' do
      before do
        allow(Backend::Api::Search).to receive(:binary).and_return(collection)
      end

      it 'returns results' do
        subject = OwnerOfContainerSearch.new.for(package).first
        expect(subject.users).to eq('maintainer' => ['Iggy'])
      end

      # the User.owner is only interesting for locked accounts
      it 'does not respect User.owner' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update_attributes(owner: develuser)

        subject = OwnerOfContainerSearch.new(devel: false, filter: 'bugowner').for(package).first
        expect(subject.users['bugowner']).to eq([user.login])
      end

      it 'respects User.state' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update_attributes(state: :locked)

        subject = OwnerOfContainerSearch.new(devel: false, filter: 'bugowner').for(package)
        expect(subject).to eq([])
      end
    end

    context '#missing' do
      it 'returns results for packages without bugowner' do
        subject = OwnerMissingSearch.new(devel: false, filter: 'bugowner').find.first
        expect(subject.rootproject).to eq('home:Iggy')
        expect(subject.project).to eq('home:Iggy')
        expect(subject.package).to eq('TestPack')
      end

      it 'returns nothing for packages with bugowner' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))

        subject = OwnerMissingSearch.new(devel: false, filter: 'bugowner').find
        expect(subject).to eq([])
      end

      it 'respects User.state' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update_attributes(state: :locked)

        subject = OwnerMissingSearch.new(devel: false, filter: 'bugowner').find.first
        expect(subject.rootproject).to eq('home:Iggy')
        expect(subject.project).to eq('home:Iggy')
        expect(subject.package).to eq('TestPack')
        expect(subject.users).to be_nil
      end

      it 'respects User.owner' do
        create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('bugowner'))
        user.update_attributes(owner: develuser)

        subject = OwnerMissingSearch.new(devel: false, filter: 'bugowner').find
        expect(subject).to eq([])

        develuser.update_attributes(state: :locked)

        subject = OwnerMissingSearch.new(devel: false, filter: 'bugowner').find.first
        expect(subject.rootproject).to eq('home:Iggy')
        expect(subject.project).to eq('home:Iggy')
        expect(subject.package).to eq('TestPack')
      end
    end

    context 'in maintenance projects' do
      let(:project) { Project.find_by(name: 'home:Iggy') }
      let!(:project_kind) { project.update_attributes(kind: 'maintenance_release') }
      let(:other_user) { create(:confirmed_user, login: 'hans') }

      # A package with bugowner develuser
      let(:package_42) { create(:package, name: 'package.42', project: project) }
      # FIXME: bugowner should be a transitive argument to the package factory
      let!(:bugowner) { create(:relationship_package_user_as_bugowner, user: develuser, package: package_42) }

      # A local link to package.42 with bugowner other_user
      let(:package) { create(:package, name: 'package', project: project) }
      # FIXME: package link should be a transitive argument to the package factory
      let!(:package_link) { package.build_backend_package.update_attributes(links_to_id: package_42) }
      let!(:other_bugowner) { create(:relationship_package_user_as_bugowner, user: other_user, package: package) }

      # A patchinfo with bugowner maintenance_user
      let(:patchinfo_42) { create(:package, name: 'patchinfo.42', project: project) }
      # FIXME: package kind should be a transitive argument to the package factory
      let!(:kind_patchinfo) { PackageKind.create(package_id: patchinfo_42.id, kind: 'patchinfo') }
      let(:maintenance_user) { create(:confirmed_user, login: 'MaintenanceIggy') }
      # FIXME: bugowner should be a transitive argument to the package factory
      let!(:maintenance_bugowner) { create(:relationship_package_user_as_bugowner, user: maintenance_user, package: patchinfo_42) }

      before do
        allow(Backend::Api::Search).to receive(:binary).and_return(maintenance_collection)
      end

      it 'respects maintenance project suffixes' do
        expect(OwnerSearch.new.for('package').first.users).to eq('bugowner' => ['hans'])
        expect(OwnerSearch.new.for('package_42').first.users).to eq('bugowner' => ['hans'])
        expect(OwnerSearch.new.for('patchinfo_42').first.users).to eq('bugowner' => ['hans'])
      end
    end
  end
end
