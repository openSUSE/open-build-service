# frozen_string_literal: true

class CopyHashedPasswordFromPasswordDigestToEncryptedPassword < ActiveRecord::Migration[7.1]
  def up
    User.in_batches do |batch|
      batch.find_each do |user|
        hashed_password = user.send(:old_password_digest)
        user.update(encrypted_password: hashed_password)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
