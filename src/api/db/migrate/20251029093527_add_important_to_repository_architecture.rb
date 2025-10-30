class AddImportantToRepositoryArchitecture < ActiveRecord::Migration[7.2]
  def change
    add_column :repository_architectures, :important, :boolean, default: false, null: false
  end
end
