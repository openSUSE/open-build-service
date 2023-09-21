# frozen_string_literal: true

class AddModeratorToRoles < ActiveRecord::Migration[7.0]
  def up
    Role.where(title: 'Moderator', global: true).first_or_create
  end

  def down
    Role.find_by(title: 'Moderator', global: true).destroy
  end
end
