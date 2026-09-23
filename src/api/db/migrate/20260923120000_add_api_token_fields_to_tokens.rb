class AddApiTokenFieldsToTokens < ActiveRecord::Migration[8.1]
  def change
    safety_assured do # since strong_migrations cannot look inside the block of change_table
      change_table :tokens, bulk: true do |t|
        t.datetime :expires_at
        t.datetime :last_used_at
      end
    end
  end
end
