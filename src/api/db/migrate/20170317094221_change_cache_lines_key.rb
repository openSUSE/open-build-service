# frozen_string_literal: true

class ChangeCacheLinesKey < ActiveRecord::Migration[5.0]
  def up
    change_column(:cache_lines, :key, :string, limit: 4096)
  end

  def down
    change_column(:cache_lines, :key, :string, limit: 255)
  end
end
