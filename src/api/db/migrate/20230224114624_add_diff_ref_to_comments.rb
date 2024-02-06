class AddDiffRefToComments < ActiveRecord::Migration[7.0]
  def up
    safety_assured do
      add_column :comments, :diff_ref, :string
    end
  end

  def down
    safety_assured do
      remove_column :comments, :diff_ref
    end
  end
end
