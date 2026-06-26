RSpec.describe UserService::Involved, :vcr do
  subject { involved_service.involved_pkg_and_prj_paginated }

  let(:user) { create(:confirmed_user, :with_home) }
  let(:home_project) { user.home_project }

  let(:some_project) { create(:project_with_package) }
  let(:some_package) { some_project.packages.first }

  let(:another_project) { create(:project, name: 'OBS:Unstable') }

  let(:non_involved_project) { create(:project_with_package) }
  let(:non_involved_package) { some_other_project.packages.first }

  let!(:project_relationship) { create(:relationship_project_user, user: user, project: some_project) }
  let!(:package_relationship) do
    create(:relationship_package_user,
           user: user,
           package: some_package,
           role: Role.find_by_title!('bugowner'))
  end

  let!(:another_project_relationship) do
    create(:relationship_project_user,
           user: user,
           project: another_project,
           role: Role.find_by_title!('bugowner'))
  end

  let(:involved_service) { described_class.new(user: user, filters: filters, page: nil) }

  before do
    User.session = user
  end

  describe '#involved_packages_and_projects' do
    context 'when there are no filters set' do
      let(:filters) { { 'search_text' => '' } }

      it 'returns all involved packages and projects of a user' do
        expect(subject).to contain_exactly(home_project, some_project, another_project, some_package)
      end
    end

    context 'when the project class filter is set' do
      let(:filters) { { 'search_text' => '', 'involved_projects' => 1 } }

      it 'returns only the involved projects of a user' do
        expect(subject).to contain_exactly(home_project, some_project, another_project)
      end
    end

    context 'when the package class filter is set' do
      let(:filters) { { 'search_text' => '', 'involved_packages' => 1 } }

      it 'returns only the involved packages of a user' do
        expect(subject).to contain_exactly(some_package)
      end
    end

    context 'when a role filter is set' do
      let(:filters) { { 'search_text' => '', 'role_bugowner' => 1 } }

      it 'returns only packages and projects where user has the corresponding role' do
        expect(subject).to contain_exactly(some_package, another_project)
      end
    end

    context 'when a role and class filter is set' do
      let(:filters) { { 'search_text' => '', 'involved_projects' => 1, 'role_bugowner' => 1 } }

      it 'returns only the elements of the corresponding class with the chosen role' do
        expect(subject).to contain_exactly(another_project)
      end
    end

    context 'when a search text is provided' do
      let(:filters) { { 'search_text' => 'obs:unstable' } }

      it 'returns only the packages and projects matching the provided string (case-insensitive)' do
        expect(subject).to contain_exactly(another_project)
      end
    end

    context 'when the owner role filter is applied without the OwnerRootProject attribute being set' do
      let(:filters) { { 'search_text' => '', 'role_owner' => 1 } }

      it 'returns no packages or projects' do
        expect(subject).to be_empty
      end
    end

    context 'when the owner role filter is applied with the OwnerRootProject attribute being set' do
      let(:filters) { { 'search_text' => '', 'role_owner' => 1 } }
      let!(:owner_root_project) { Attrib.create!(attrib_type: AttribType.find_by(name: 'OwnerRootProject'), project: some_project) }

      it 'returns only the owned packages and projects' do
        expect(subject).to contain_exactly(some_project, some_package)
      end
    end

    context 'when the owner role filter is applied in combination with another role filter' do
      let(:filters) { { 'search_text' => '', 'role_owner' => 1, 'role_bugowner' => 1 } }
      let!(:owner_root_project) { Attrib.create!(attrib_type: AttribType.find_by(name: 'OwnerRootProject'), project: some_project) }

      it 'returns projects and packages of the selected role and the owned ones' do
        expect(subject).to contain_exactly(some_project, some_package, another_project)
      end
    end

    context 'when the owner role filter is applied in combination with a class filter' do
      let(:filters) { { 'search_text' => '', 'role_owner' => 1, 'involved_packages' => 1 } }
      let!(:owner_root_project) { Attrib.create!(attrib_type: AttribType.find_by(name: 'OwnerRootProject'), project: some_project) }

      it 'returns projects and packages of the selected role and the owned ones' do
        expect(subject).to contain_exactly(some_package)
      end
    end
  end
end
