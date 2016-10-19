require 'api_exception'

# The Role class represents a role in the database. Roles can have permissions
# associated with themselves. Roles can assigned be to roles and groups.
#
# The Role ActiveRecord class mixes in the "ActiveRbacMixins::RoleMixins::*" modules.
# These modules contain the actual implementation. It is kept there so
# you can easily provide your own model files without having to all lines
# from the engine's directory
class Role < ApplicationRecord
  class NotFound < APIException
    setup 404
  end

  validates_format_of :title,
                      :with => %r{\A\w*\z},
                      :message => 'must not contain invalid characters.'
  validates_length_of :title,
                      :in => 2..100,
                      :too_long => 'must have less than 100 characters.',
                      :too_short => 'must have more than two characters.',
                      :allow_nil => false

  # We want to validate a role's title pretty thoroughly.
  validates_uniqueness_of :title,
                          :message => 'is the name of an already existing role.'

  belongs_to :groups_roles
  belongs_to :attrib_type_modifiable_bies
  belongs_to :relationships
  belongs_to :roles_static_permissions
  belongs_to :roles_users

  # roles have n:m relations for users
  has_and_belongs_to_many :users, -> { uniq() }
  # roles have n:m relations to groups
  has_and_belongs_to_many :groups, -> { uniq() }
  # roles have n:m relations to permissions
  has_and_belongs_to_many :static_permissions, -> { uniq() }

  scope :global, -> { where(global: true) }

  after_save :discard_cache
  after_destroy :discard_cache

  def self.discard_cache
    @cache = nil
  end

  def self.rolecache
    @cache || self.create_cache
  end

  def self.create_cache
    # {"Admin" => #<Role id:1>, "downloader" => #<Role id:2>, ... }
    @cache = Hash[Role.all.map { |role| [role.title, role] }]
  end

  def self.find_by_title!(title)
    find_by_title(title) || raise(NotFound.new("Couldn't find Role '#{title}'"))
  end

  def self.local_roles
    %w(maintainer bugowner reviewer downloader reader).map { |r| Role.rolecache[r] }
  end

  def self.global_roles
    %w(Admin User)
  end

  def rolecache
    self.class.rolecache
  end

  def discard_cache
    self.class.discard_cache
  end

  def self.ids_with_permission(perm_string)
    RolesStaticPermission.joins(:static_permission).
      where(:static_permissions => { :title => perm_string } ).
      select('role_id').pluck(:role_id)
  end

  def to_param
    title
  end

  def to_s
    title
  end
end
