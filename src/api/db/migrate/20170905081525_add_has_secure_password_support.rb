class AddHasSecurePasswordSupport < ActiveRecord::Migration[5.1]
  def change
    rename_column :users, :password, :deprecated_password
    rename_column :users, :password_hash_type, :deprecated_password_hash_type
    rename_column :users, :password_salt, :deprecated_password_salt

    change_column :users, :deprecated_password, :string, null: true, default: nil, after: :realname
    change_column :users, :deprecated_password_hash_type, :string, null: true, default: nil, after: :deprecated_password
    change_column :users, :deprecated_password_salt, :string, null: true, default: nil, after: :deprecated_password_hash_type

    add_column :users, :password_digest, :string, after: :realname
  end
end
