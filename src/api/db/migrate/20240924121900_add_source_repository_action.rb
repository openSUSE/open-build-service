class AddSourceRepositoryAction < ActiveRecord::Migration[7.0]
  def change
    add_column :bs_request_actions, :source_repository, :string, collation: 'utf8_unicode_ci'
  end
end
