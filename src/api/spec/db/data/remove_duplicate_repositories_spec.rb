# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20170306084550_remove_duplicate_repositories.rb')
require Rails.root.join('db/migrate/20170306084558_change_repositories_remote_project_name_to_not_null.rb')

RSpec.describe RemoveDuplicateRepositories, type: :migration do
  # This migration does not allow NULL values for remote_project_name column
  # We need this migration to not be run to create test data
  # 20170306084558_change_repositories_remote_project_name_to_not_null.rb
  let(:schema_migration) { ChangeRepositoriesRemoteProjectNameToNotNull.new }
  let(:data_migration) { RemoveDuplicateRepositories.new }

  describe '.up' do
    before do
      schema_migration.down
    end

    after do
      DataMigrate::DataSchemaMigration.find_or_create_by(version: 20_170_306_084_550.to_s)
      schema_migration.up
    end

    # We need to set Repository.deleted_instance.remote_project_name = '',
    # because reverting the schema_migration will set the default value of remote_project_name
    # to NULL. In the :cleanup_before_destroy callback in repository, associated path elements get
    # associated with a global deleted repository (Repository.deleted_instance) which
    # uses Repository.find_or_create_by(..).
    # This would fail as there is a repository model validation which does not allow nil values.
    let!(:deleted_repository) { create(:repository, name: 'deleted', remote_project_name: '', project: Project.deleted_instance) }

    let(:remote_project) { create(:remote_project) }
    let!(:remote_repository) { create(:repository, project: remote_project, name: 'standard', remote_project_name: 'openSUSE.org:Foo') }
    let!(:remote_repository_with_same_name) do
      create(:repository, project: remote_project, name: 'standard', remote_project_name: 'openSUSE.org:Bar')
    end

    let(:project) { create(:project) }
    let!(:repository) do
      # we need to bypass the validation to sneek in the nil value for remote_project_name which this data migration will fix
      r = build(:repository, project: project, name: 'standard', remote_project_name: nil, architectures: ['x86_64', 'i586'])
      r.save(validate: false)
      r
    end
    let!(:duplicate_repository) do
      # we need to bypass the validation to sneek in the nil value for remote_project_name which this data migration will fix
      r = build(:repository, project: project, name: 'standard', remote_project_name: nil, architectures: ['x86_64', 'i586'])
      r.save(validate: false)
      r
    end
    let!(:path_element) { create(:path_element, link: repository, repository: remote_repository) }
    let!(:duplicate_path_element) { create(:path_element, link: duplicate_repository, repository: remote_repository) }

    it 'removes the local and duplicate repository' do
      expect do
        data_migration.up
      end.to change(Repository, :count).by(-1)

      expect(Repository.all).to include(repository)
      expect(Repository.all).to include(remote_repository)
      expect(Repository.all).to include(remote_repository_with_same_name)
      expect(Repository.all).not_to include(duplicate_repository)
    end

    it 'moves duplicate path elements link to the deleted repository' do
      data_migration.up
      duplicate_path_element.reload
      path_element.reload
      expect(duplicate_path_element.link).to eq(deleted_repository)
      expect(path_element.link).to eq(repository)
    end
  end
end
