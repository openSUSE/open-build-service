class ChangeCacheLinesKey < ActiveRecord::Migration[5.0]
  def change
    change_column(:cache_lines, :key, :string, limit: 4096)
  end
end
