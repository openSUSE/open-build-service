# This class represents a "static permission" dataset in the database. A
# static permission basically only is a string that can be attached to a
# role. You can then check for it being assigned to a role in your application
# code.
#
class StaticPermission < ApplicationRecord
  has_many :roles_static_permissions

  has_and_belongs_to_many :roles, -> { distinct }

  # We want to validate a static permission's title pretty thoroughly.
  validates_uniqueness_of :title,
                          message: 'is the name of an already existing static permission.'
  validates_presence_of :title, message: 'must be given.'

  validates_format_of :title, with: %r{\A[\w\-]*\z},
                          message: 'must not contain invalid characters.'

  alias_attribute :fixtures_name, :title
end
