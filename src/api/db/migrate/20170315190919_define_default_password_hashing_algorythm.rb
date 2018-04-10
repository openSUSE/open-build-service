# frozen_string_literal: true
class DefineDefaultPasswordHashingAlgorythm < ActiveRecord::Migration[5.0]
  def up
    change_column_default(:users, :password_hash_type, 'md5')
  end

  def down
    change_column_default(:users, :password_hash_type, '')
  end
end
