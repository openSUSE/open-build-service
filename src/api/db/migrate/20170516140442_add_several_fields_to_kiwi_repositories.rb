# frozen_string_literal: true

class AddSeveralFieldsToKiwiRepositories < ActiveRecord::Migration[5.0]
  def change
    add_column :kiwi_repositories, :alias, :string
    add_column :kiwi_repositories, :imageinclude, :boolean
    add_column :kiwi_repositories, :password, :string
    add_column :kiwi_repositories, :prefer_license, :boolean
    add_column :kiwi_repositories, :replaceable, :boolean
    add_column :kiwi_repositories, :username, :string
  end
end
