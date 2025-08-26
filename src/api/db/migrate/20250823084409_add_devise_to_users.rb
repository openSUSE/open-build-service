# frozen_string_literal: true

class AddDeviseToUsers < ActiveRecord::Migration[7.2]
  def change
    safety_assured do # since strong_migrations cannot look inside the block of change_table
      change_table :users do |t|
        t.string :encrypted_password, null: false, default: '', charset: 'utf8'
      end
    end
  end
end
