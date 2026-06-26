class AddDiffRefToComments < ActiveRecord::Migration[7.0]
  def change
    add_column :comments, :diff_ref, :string
  end
end
