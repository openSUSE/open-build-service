class AddDiffRefToComments < ActiveRecord::Migration[6.1]
  def change
    add_column :comments, :diff_ref, :string
  end
end
