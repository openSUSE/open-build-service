# frozen_string_literal: true

class DropPasswordCryptedFromUsers < ActiveRecord::Migration[5.0]
  def up
    remove_column :users, :password_crypted
  end

  def down
    add_column :users, :password_crypted, :string
  end
end
