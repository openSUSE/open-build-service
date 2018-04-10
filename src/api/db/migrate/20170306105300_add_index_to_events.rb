# frozen_string_literal: true

class AddIndexToEvents < ActiveRecord::Migration[5.0]
  def self.up
    add_index :events, :mails_sent
  end

  def self.down
    remove_index :events, :mails_sent
  end
end
