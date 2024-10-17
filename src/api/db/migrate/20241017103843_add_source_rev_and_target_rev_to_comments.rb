class AddSourceRevAndTargetRevToComments < ActiveRecord::Migration[7.0]
  def change
    add_column :comments, :source_rev, :string
    add_column :comments, :target_rev, :string
  end
end
