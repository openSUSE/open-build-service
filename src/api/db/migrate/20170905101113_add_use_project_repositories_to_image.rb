# frozen_string_literal: true
class AddUseProjectRepositoriesToImage < ActiveRecord::Migration[5.1]
  def change
    add_column :kiwi_images, :use_project_repositories, :boolean, default: false
  end
end
