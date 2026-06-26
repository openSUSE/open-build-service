RSpec.describe ProjectLinks do
  # Project includes the ProjectLinks concern, so we test the behaviour through it.
  let(:project) { create(:project, name: 'home:Iggy') }

  describe '#add_project_link' do
    context 'with a local project' do
      let!(:project_to_link_against) { create(:project, name: 'local_target') }

      it 'creates a new LinkedProject' do
        expect { project.add_project_link(project_name_to_link_against: project_to_link_against.name) }.to change(LinkedProject, :count).by(1)
      end

      it 'links to the local project' do
        project.add_project_link(project_name_to_link_against: project_to_link_against.name)
        expect(project.linking_to.last.linked_db_project).to eq(project_to_link_against)
      end

      it 'sets the position to 1 for the first link (handled by acts_as_list)' do
        project.add_project_link(project_name_to_link_against: project_to_link_against.name)
        expect(project.linking_to.last.position).to eq(1)
      end

      it 'appends subsequent links to the bottom of the list (handled by acts_as_list)' do
        another_project = create(:project, name: 'another_target')
        project.add_project_link(project_name_to_link_against: project_to_link_against.name)
        project.add_project_link(project_name_to_link_against: another_project.name)
        expect(project.linking_to.last.position).to eq(2)
      end

      it 'does not create a duplicate link for the same project' do
        project.add_project_link(project_name_to_link_against: project_to_link_against.name)
        expect { project.add_project_link(project_name_to_link_against: project_to_link_against.name) }.not_to change(LinkedProject, :count)
      end
    end

    context 'with a remote project' do
      let!(:interconnect) { create(:remote_project, name: 'remote_obs') }
      let(:remote_project_name) { 'remote_obs:remote_project' }

      before do
        allow(Project).to receive(:remote_project?).with(remote_project_name).and_return(true)
      end

      it 'creates a new LinkedProject' do
        expect { project.add_project_link(project_name_to_link_against: remote_project_name) }.to change(LinkedProject, :count).by(1)
      end

      it 'stores the remote project name' do
        project.add_project_link(project_name_to_link_against: remote_project_name)
        expect(project.linking_to.last.linked_remote_project_name).to eq(remote_project_name)
      end

      it 'does not set a local linked_db_project' do
        project.add_project_link(project_name_to_link_against: remote_project_name)
        expect(project.linking_to.last.linked_db_project).to be_nil
      end
    end

    context 'with a non-existing project' do
      it 'fails with an exception' do
        expect { project.add_project_link(project_name_to_link_against: 'nonexisting') }.to raise_error(Project::Errors::UnknownObjectError)
      end
    end
  end

  describe '#remove_project_link' do
    context 'with a local project' do
      let!(:linked_project) { create(:project, name: 'local_target') }

      before do
        project.add_project_link(project_name_to_link_against: linked_project.name)
      end

      it 'removes the existing link' do
        expect { project.remove_project_link(linked_project_name: linked_project.name) }.to change(LinkedProject, :count).by(-1)
      end

      it 'leaves no link to the project behind' do
        project.remove_project_link(linked_project_name: linked_project.name)
        expect(project.reload.projects_linking_to).not_to include(linked_project)
      end

      it 'does nothing when the link does not exist' do
        other_project = create(:project, name: 'not_linked')
        expect { project.remove_project_link(linked_project_name: other_project.name) }.not_to change(LinkedProject, :count)
      end
    end

    context 'with a remote project' do
      let!(:interconnect) { create(:remote_project, name: 'remote_obs') }
      let(:remote_project_name) { 'remote_obs:remote_project' }

      before do
        allow(Project).to receive(:remote_project?).with(remote_project_name).and_return(true)
        project.add_project_link(project_name_to_link_against: remote_project_name)
      end

      it 'removes the existing remote link' do
        expect { project.remove_project_link(linked_project_name: remote_project_name) }.to change(LinkedProject, :count).by(-1)
      end
    end

    context 'with a non-existing project' do
      it 'fails with an exception' do
        expect { project.remove_project_link(linked_project_name: 'nonexisting') }.to raise_error(Project::Errors::UnknownObjectError)
      end
    end
  end
end
