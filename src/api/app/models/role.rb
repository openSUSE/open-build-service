# The Role class represents a role in the database. Roles can have permissions
# associated with themselves. Roles can assigned be to roles and groups.
#
# The Role ActiveRecord class mixes in the "ActiveRbacMixins::RoleMixins::*" modules.
# These modules contain the actual implementation. It is kept there so
# you can easily provide your own model files without having to all lines
# from the engine's directory
class Role < ActiveRecord::Base

  validates_format_of :title,
                      :with => %r{^[\w \$\^\-\.#\*\+&'"]*$},
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
  belongs_to :package_group_role_relationships
  belongs_to :package_user_role_relationships
  belongs_to :project_group_role_relationships
  belongs_to :project_user_role_relationships
  belongs_to :roles_static_permissions
  belongs_to :roles_users

  # roles have n:m relations for users
  has_and_belongs_to_many :users, :uniq => true
  # roles have n:m relations to groups
  has_and_belongs_to_many :groups, :uniq => true
  # roles have n:m relations to permissions
  has_and_belongs_to_many :static_permissions, :uniq => true
  # protect users and groups from mass assigning - we want to do those
  # manually
  attr_protected :users, :static_permissions

  scope :global, where(:global => true)

  class << self
    def rolecache
      return @cache if @cache
      @cache = Hash.new
      all.each do |role|
        @cache[role.title] = role
      end
      return @cache
    end

    def get_by_title(title)
      r = where("title = BINARY ?", title).first
      raise RoleNotFoundError.new( "Error: Role '#{title}' not found." ) unless r
      return r
    end
  end

  def rolecache
    self.class.rolecache
  end

  def after_create
    logger.debug "updating role cache (new role '#{title}', id \##{id})"
    rolecache[title] = self
  end

  def after_update
    logger.debug "updating role cache (role name for id \##{id} changed to '#{title}')"
    rolecache.each do |k,v|
      if v.id == id
        rolecache.delete k
        break
      end
    end
    rolecache[title] = self
  end

  def after_destroy
    logger.debug "updating role cache (role '#{title}' deleted)"
    rolecache.delete title
  end

  def self.ids_with_permission(perm_string)
    RolesStaticPermission.joins(:static_permission).where(:static_permissions => { :title => perm_string } ).select("role_id").map { |rs| rs.role_id }
  end

end
