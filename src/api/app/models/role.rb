require 'api_exception'

# The Role class represents a role in the database. Roles can have permissions
# associated with themselves. Roles can assigned be to roles and groups.
#
# The Role ActiveRecord class mixes in the "ActiveRbacMixins::RoleMixins::*" modules.
# These modules contain the actual implementation. It is kept there so
# you can easily provide your own model files without having to all lines
# from the engine's directory
class Role < ActiveRecord::Base

  class NotFound < APIException
    setup 404
  end

  validates_format_of :title,
                      :with => %r{\A\w*\z},
                      :message => 'must not contain invalid characters.'
  validates_length_of :title,
                      :in => 2..100, :allow_nil => true,
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

  class << self
    def discard_cache
      @cache = nil
    end

    def rolecache
      return @cache if @cache
      @cache = Hash.new
      all.each do |role|
        @cache[role.title] = role
      end
      return @cache
    end

    def get_by_title(title)
      find_by_title(title) or raise NotFound.new("Couldn't find Role '#{title}'")
    end
    def local_roles
      Array[ "maintainer", "bugowner", "reviewer", "downloader" , "reader"]
    end
    def global_roles
      Array[ "Admin", "User"]
    end
  end

  def rolecache
    self.class.rolecache
  end

  def discard_cache
    self.class.discard_cache
  end

  after_save :discard_cache
  after_destroy :discard_cache

  def self.ids_with_permission(perm_string)
    RolesStaticPermission.joins(:static_permission).where(:static_permissions => { :title => perm_string } ).select("role_id").map { |rs| rs.role_id }
  end

end
