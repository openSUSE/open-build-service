# This class represents a "static permission" dataset in the database. A
# static permission basically only is a string that can be attached to a
# role. You can then check for it being assigned to a role in your application
# code.
#
class StaticPermission < ApplicationRecord
  has_many :roles_static_permissions

  has_and_belongs_to_many :roles, -> { distinct }

  # We want to validate a static permission's title pretty thoroughly.
  validates :title,
            uniqueness: { message: 'is the name of an already existing static permission' }
  validates :title, presence: { message: 'must be given.' }

  validates :title, format: { with:    %r{\A[\w\-]*\z},
                              message: 'must not contain invalid characters' }

  alias_attribute :fixtures_name, :title
end

# == Schema Information
#
# Table name: static_permissions
#
#  id    :integer          not null, primary key
#  title :string(200)      default(""), not null, indexed
#
# Indexes
#
#  static_permissions_title_index  (title) UNIQUE
#
