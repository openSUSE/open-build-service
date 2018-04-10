# frozen_string_literal: true
class AddStItoTokens < ActiveRecord::Migration[5.0]
  def change
    add_column :tokens, :type, :string
  end
end
