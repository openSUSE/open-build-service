class AddRequiredChecksToRepositoryArchitecture < ActiveRecord::Migration[5.2]
  def change
    add_column :repository_architectures, :required_checks, :string
  end
end
