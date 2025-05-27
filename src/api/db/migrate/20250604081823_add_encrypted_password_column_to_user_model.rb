class AddEncryptedPasswordColumnToUserModel < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :encrypted_password, :string
  end
end
