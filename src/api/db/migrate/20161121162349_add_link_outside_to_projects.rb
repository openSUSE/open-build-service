# frozen_string_literal: true

class AddLinkOutsideToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :url, :string, null: true
  end
end
