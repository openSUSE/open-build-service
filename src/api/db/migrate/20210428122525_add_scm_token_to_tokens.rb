class AddScmTokenToTokens < ActiveRecord::Migration[6.0]
  def change
    safety_assured do # since strong_migrations cannot look inside the block of change_table
      change_table :tokens, bulk: true do |t|
        t.string :scm_token
        t.index :scm_token
      end
    end
  end
end
