class RemoveDiffRefFromComments < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :comments, :diff_ref, :string }
  end
end
