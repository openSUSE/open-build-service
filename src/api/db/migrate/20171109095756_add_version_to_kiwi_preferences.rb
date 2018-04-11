# frozen_string_literal: true

class AddVersionToKiwiPreferences < ActiveRecord::Migration[5.1]
  def change
    add_column :kiwi_preferences, :version, :string
  end
end
