# frozen_string_literal: true
class AddLocalUserFlag < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :ignore_auth_services, :boolean, default: false
  end
end
