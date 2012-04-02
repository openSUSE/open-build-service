require 'active_rbac_mixins/role_mixins'

# The Role class represents a role in the database. Roles can have permissions
# associated with themselves. Roles can assigned be to roles and groups.
#
# The Role ActiveRecord class mixes in the "ActiveRbacMixins::RoleMixins::*" modules.
# These modules contain the actual implementation. It is kept there so
# you can easily provide your own model files without having to all lines
# from the engine's directory
class Role < ActiveRecord::Base
  include ActiveRbacMixins::RoleMixins::Validation
  include ActiveRbacMixins::RoleMixins::Core

  has_many :project_user_role_relationships

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
end
