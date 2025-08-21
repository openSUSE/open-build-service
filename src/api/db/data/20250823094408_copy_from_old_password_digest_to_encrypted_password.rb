# frozen_string_literal: true

class CopyFromOldPasswordDigestToEncryptedPassword < ActiveRecord::Migration[7.2]
  def up
    User.where.not(old_password_digest: nil).in_batches do |batch|
      batch.find_each do |user|
        user.update_columns(encrypted_password: user.old_password_digest) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def down; end
end
