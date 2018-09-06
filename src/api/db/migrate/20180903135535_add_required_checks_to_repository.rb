class AddRequiredChecksToRepository < ActiveRecord::Migration[5.2]
  def change
    add_column :repositories, :required_checks, :string
  end
end
