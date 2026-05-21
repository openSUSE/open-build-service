RSpec.describe Project, '.find_package' do
  # follow_multibuild is tested in spec/models/concerns/multibuild_package_spec.rb
  # use_source is tested in spec/models/user_has_local_permission_spec.rb

  subject { project.find_package(package.name) }

  let(:package) { create(:package) }
  let(:project) { package.project }

  context 'local package' do
    it { expect(subject).to eq(package) }
  end

  context 'project links' do
    # By default find_package will "follow" project links and tries to find the Package from the Project the link points to.
    # https://github.com/openSUSE/open-build-service/wiki/Links#project-links
    subject { project.find_package(package.name) }

    let(:link_target) { create(:project) }
    let(:project) { create(:project, link_to: link_target) }

    context 'and local project provides package and linked project not' do
      let(:package) { create(:package, project: project) }

      it 'returns the package from the link' do
        expect(subject.project).equal?(link_target) # rubocop:disable RSpec/MissingExpectationTargetMethod -- FIXME
      end
    end

    context 'and linked project provides package and local project not' do
      let(:package) { create(:package, project: link_target) }

      it 'returns the package from the link' do
        expect(subject.project).to eq(link_target)
      end
    end

    context 'and linked project provides package and local project also provides package' do
      let(:package_in_linked_project) { create(:package, project: link_target) }
      let(:package) { create(:package, name: package_in_linked_project.name, project: project) }

      it 'returns the package from the link' do
        expect(subject.project).equal?(link_target) # rubocop:disable RSpec/MissingExpectationTargetMethod -- FIXME
      end
    end

    context 'and linked project does not provide package and local project also not' do
      let(:package) { build(:package, name: 'i_do_not_exist') }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  context 'check_update_project enabled' do
    # With `check_update_project: true` it will "follow" those types of links and finds the Package from the Project the link points to.
    # https://github.com/openSUSE/open-build-service/wiki/Links#update-instance-project-links
    subject { project.find_package(package.name, true) }

    let(:update_project) { create(:project) }
    let(:project) do
      project = create(:project)
      create(:update_project_attrib, project: project, update_project: update_project)
      project
    end

    context 'and linked project provides package and local project not' do
      let(:package) { create(:package, project: update_project) }

      it 'returns the package from the link' do
        expect(subject.project).to eq(update_project)
      end
    end

    context 'and local project provides package and linked project not' do
      let(:package) { create(:package, project: project) }

      it 'returns the package from the local project' do
        expect(subject.project).to eq(project)
      end
    end

    context 'and linked project provides package and local project also provides package' do
      let(:updated_package) { create(:package, project: update_project) }
      let(:package) { create(:package, name: updated_package.name, project: project) }

      it 'returns the package from the link' do
        expect(subject.project).to eq(update_project)
      end
    end

    context 'and linked project does not provide package and local project also not' do
      let(:package) { build(:package, name: 'i_do_not_exist') }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
