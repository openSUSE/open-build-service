require 'rails_helper'

RSpec.describe MetaControllerService::ProjectUpdater do
  let(:project) { create(:project, name: 'openSUSE_41') }
  let(:admin_user) { create(:admin_user, login: 'Admin') }

  before do
    User.session = admin_user
  end

  context 'with valid meta' do
    let(:meta) do
      <<-HEREDOC
      <project name="#{project.name}">
      <title/><description/>
      </project>
      HEREDOC
    end

    let(:project_updater) { MetaControllerService::ProjectUpdater.new(project: project, request_data: Xmlhash.parse(meta)) }

    before do
      project_updater.call
    end

    describe '#valid?' do
      it { expect(project_updater).to be_valid }
    end

    describe '#errors' do
      it { expect(project_updater.errors).to be_blank }
    end
  end

  context 'with nonexistent path' do
    let(:meta) do
      <<-HEREDOC
      <project name="#{project.name}">
      <title/>
      <description/>
      <repository name="not-existent">
      <path project="not-existent" repository="standard" />
      </repository>
      </project>
      HEREDOC
    end

    let(:project_updater) { MetaControllerService::ProjectUpdater.new(project: project, request_data: Xmlhash.parse(meta)) }

    before do
      project_updater.call
    end

    describe '#valid?' do
      it { expect(project_updater).not_to be_valid }
    end

    describe '#errors' do
      let(:error_message) { 'A project with the name not-existent does not exist. Please update the repository path elements.' }

      it { expect(project_updater.errors).to eq(error_message) }
    end
  end
end
