require 'rails_helper'

RSpec.describe Staging::StagingProjectCreator do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }
  let!(:staging_workflow) { create(:staging_workflow, project: project) }
  let(:staging_project_creator) { Staging::StagingProjectCreator.new(staging_projects[project_names], staging_workflow, user) }

  let(:staging_projects) do
    lambda do |project_names|
      Builder::XmlMarkup.new.workflow do |workflow|
        project_names.each { |project_name| workflow.staging_project(project_name) }
      end
    end
  end

  before do
    User.session = user
  end

  describe '#staging_projects' do
    let(:project_names) { ["#{project}:Staging:C", "#{project}:Staging:D"] }

    it { expect(staging_project_creator.staging_projects).not_to be_nil }
  end

  describe '#call' do
    subject { staging_project_creator.call }

    context 'succeeds' do
      context 'with non-existent projects' do
        let(:project_names) { ["#{project}:Staging:C", "#{project}:Staging:D"] }

        describe '#valid?' do
          it { expect(subject).to be_valid }
        end

        describe '#errors' do
          it { expect(subject.errors).to be_empty }
        end

        it { expect { subject }.to change(Project, :count).by(2) }
        it { expect { subject }.to change(ProjectLogEntry, :count).by(2) }
      end

      context 'with an existent project' do
        let!(:other_project) { create(:project, name: "#{project}:other_project") }
        let(:project_names) { ["#{project}:Staging:C", other_project.to_s] }

        describe '#valid?' do
          it { expect(subject).to be_valid }
        end

        describe '#errors' do
          it { expect(subject.errors).to be_empty }
        end

        it { expect { subject }.to change(Project, :count).by(1) }
        it { expect { subject }.to change(ProjectLogEntry, :count).by(2) }
      end
    end

    context 'fails' do
      context 'with projects assgined to a staging workflow' do
        let(:project_names) { ["#{project}:Staging:A", "#{project}:Staging:D"] }

        describe '#valid?' do
          it { expect(subject).not_to be_valid }
        end

        describe '#errors' do
          let(:error_message) { ['Project "home:tom:Staging:A": is already assigned to a staging workflow.'] }

          it { expect(subject.errors).to eq(error_message) }
        end

        it { expect { subject }.not_to change(Project, :count) }
        it { expect { subject }.not_to change(ProjectLogEntry, :count) }
      end

      context 'with a staging workflow main project' do
        let(:project_names) { ["#{project}:Staging:D", project.to_s] }

        describe '#valid?' do
          it { expect(subject).not_to be_valid }
        end

        describe '#errors' do
          let(:error_message) { ['Project "home:tom": has a staging already. Nested stagings are not supported.'] }

          it { expect(subject.errors).to eq(error_message) }
        end

        it { expect { subject }.not_to change(Project, :count) }
        it { expect { subject }.not_to change(ProjectLogEntry, :count) }
      end

      context 'without an existing parent project' do
        let(:project_names) { ['NoneFatherProject:Staging:D', "#{project}:Staging:D"] }

        describe '#valid?' do
          it { expect(subject).not_to be_valid }
        end

        describe '#errors' do
          let(:error_message) { ['Project "NoneFatherProject:Staging:D": you are not allowed to create this project.'] }

          it { expect(subject.errors).to eq(error_message) }
        end

        it { expect { subject }.not_to change(Project, :count) }
        it { expect { subject }.not_to change(ProjectLogEntry, :count) }
      end
    end
  end
end
