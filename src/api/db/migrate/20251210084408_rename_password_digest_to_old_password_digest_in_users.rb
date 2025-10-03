class RenamePasswordDigestToOldPasswordDigestInUsers < ActiveRecord::Migration[7.2]
  def change
    safety_assured { rename_column :users, :password_digest, :encrypted_password }
  end
end
