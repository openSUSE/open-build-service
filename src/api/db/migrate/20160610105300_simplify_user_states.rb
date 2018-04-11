# frozen_string_literal: true

class SimplifyUserStates < ActiveRecord::Migration[4.2]
  def self.up
    # new state enum
    execute "ALTER TABLE users add column new_state enum('unconfirmed', 'confirmed', 'locked', 'deleted') DEFAULT 'unconfirmed'"

    # transfer only the good states, "ichainrequest" stays "unconfirmed".
    execute "UPDATE users SET new_state = 'confirmed' where state = 2;"
    execute "UPDATE users SET new_state = 'locked'    where state = 3;"
    execute "UPDATE users SET new_state = 'deleted'   where state = 4;"
    # "retrieved_password" becomes also "confirmed"
    execute "UPDATE users SET new_state = 'confirmed' where state = 6;"

    remove_column :users, :state
    rename_column :users, :new_state, :state
  end

  def self.down
    # new state enum
    execute 'ALTER TABLE users add column old_state int;'

    execute "UPDATE users SET old_state = 1 where state = 'unconfirmed';"
    execute "UPDATE users SET old_state = 2 where state = 'confirmed';"
    execute "UPDATE users SET old_state = 3 where state = 'locked';"
    execute "UPDATE users SET old_state = 4 where state = 'deleted';"

    remove_column :users, :state
    rename_column :users, :old_state, :state
  end
end
