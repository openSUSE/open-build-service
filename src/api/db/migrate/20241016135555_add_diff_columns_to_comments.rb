class AddDiffColumnsToComments < ActiveRecord::Migration[7.0]
  def change
    add_column :comments, :diff_file_index, :integer
    add_column :comments, :diff_line_number, :integer
  end
end
