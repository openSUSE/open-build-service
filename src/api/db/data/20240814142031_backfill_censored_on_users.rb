# frozen_string_literal: true

class BackfillCensoredOnUsers < ActiveRecord::Migration[7.0]
  def up
    return unless User.columns.any? { |c| c.name == 'blocked_from_commenting' }

    User.where(blocked_from_commenting: true).in_batches do |batch|
      batch.find_each do |user|
        user.update(censored: user.blocked_from_commenting)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
