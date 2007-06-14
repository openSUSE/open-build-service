# The AnonymousUser class is a mock version of the User class. It provides
# the functionality that is relevant for the places where you do not need
# a logged in user but do not want to differentiate between "no user"
# and "a logged in user".
#
# This means, for example, that you can check for an AnonymousUser to have
# a certain role, group and also access its login and email. However, you
# cannot set any value of it through its instances.
#
# The AnonymousUser class implements the singleton pattern. Use AnonymousUser.instance
# to retrive the Singleton instance.
# The method "current_user" of the ApplicationControllerMixin and the RbacHelper
# will return the currently logged in user or the anonymous user when called.
# They will never return nil.
#
# You can configure the AnonymousUser instance by setting the :anonymous_user
# configuration value. For example, you could have the following in your
# <em>environment.rb</em>:
#
# <pre>
# module ActiveRbacConfig
#   config :anonymous_user_login, 'Anonymous User'
#   config :anonymous_user_email, 'nobody@localhost'
#   config :anonymous_user_roles,  [ 'Nobody' ]
#   config :anonymous_user_groups, [ 'Everybody' ]
# end
# </pre>
#
# You can set the following configuration settings:
#
# <dl>
#   <dt>:anonymous_user_login</dt>
#   <dd>The login value for the anonymous user.</dd>
#
#   <dt>:anonymous_user_email</dt>
#   <dd>The email adress to assume for the anonymous user.</dd>
#
#   <dt>:anonymous_user_roles, :anonymous_user_groups</dt>
#   <dd>The roles and groups the anonymous user has. You have to
#       specify the role's/group's "title" value.</dd>
# </dl>
#
# The existance of the AnonymousUser class makes many things simpler. For
# example, you can write the following in your templates
#
# <pre>
#   <% if current_user.has_role?('Admin') %>Hello, Admin<% end %>
# </pre>
#
# instead of
#
# <pre>
#  <% if !current_user.nil? and current_user.has_role?('Admin') %>Hello, 
#  Admin<% end %>
# </pre>
#
# The same is true for your controllers.

class AnonymousUser
  include Singleton
  
  # Always returns -1 so the id cannot be equal to any ActiveRecord's id
  # property (assuming you do not allow negative ids).
  def id
    -1
  end
  
  # Returns the current point of time in a DateTime object.
  def created_at
    return DateTime.new
  end
  
  # Alias to created_at so it also returns the current point of time.
  alias_method :updated_at, :created_at

  # Alias to created_at so it also returns the current point of time.
  alias_method :last_updated_at, :created_at
  
  # Always returns 0
  def login_failure_count
    0
  end
  
  # Returns the login of the anonymous user as configured.
  def login
    ActiveRbac.anonymous_user_login
  end
  
  # Returns the email adress of the anonymous user as configured.
  def email
    ActiveRbac.anonymous_user_email
  end
  
  # Always eturns the value for "confirmed".
  def state
    User.states['confirmed']
  end

  # Returns the Role objects this user has been assigned (ActiveRecord
  # Role objects).
  def roles
    # return already fetched roles
    return @roles unless @roles.nil?
    
    # fetch the role objects for the configured role titles otherwise
    @roles = ActiveRbac.anonymous_user_roles.collect do |role_title|
      Role.find_by_title role_title
    end
    
    return @roles
  end

  # Returns all roles and all of their parents as well as all the
  # roles being assigned through the groups.
  def all_roles
    return @all_roles unless @all_roles.nil?
    
    @all_roles = Array.new

    for role in roles
      @all_roles << role.ancestors_and_self
    end

    for group in groups
      @all_roles << group.all_roles
    end

    @all_roles.flatten!
    @all_roles.uniq!

    return @all_roles
  end

  # Returns the Group objects this user has been assigned (ActiveRecord
  # Group objects).
  def groups
    # return already fetched roles
    return @groups unless @groups.nil?
    
    # fetch the role objects for the configured role titles otherwise
    @groups = ActiveRbac.anonymous_user_groups.collect do |groups_title|
      Group.find_by_title groups_title
    end
    
    return @groups
  end

  # Returns all groups and all parent groups.
  def all_groups
    return @all_groups unless @all_groups.nil?

    @all_groups = Array.new

    for group in groups
      @all_groups << group.ancestors_and_self
    end

    @all_groups.flatten!
    @all_groups.uniq!

    return @all_groups
  end

  # Returns all StaticPermissions that have been assigned to the 
  # anonymous user through all of his roles.
  def all_static_permissions
    return @permissions unless @permissions.nil?
    
    @permissions = Array.new

    all_roles.each do |role|
      @permissions.concat(role.static_permissions)
    end

    return @permissions
  end

  # This method returns true if the user is granted the permission with one
  # of the given permission titles.
  def has_permission?(*permission_titles)
    all_roles.detect do |role| 
      role.static_permissions.detect do |permission|
        permission_titles.include?(permission.title)
      end
    end
  end

  # This method returns true if the user is assigned the role with one of the
  # role titles given as parameters. False otherwise.
  def has_role?(*role_titles)
    obj = all_roles.detect do |role| 
            role_titles.include?(role.title)
          end
    
    return !obj.nil?
  end

  # Returns true. Yes, this is the AnonymousUser class - what did you expect?
  def is_anonymous?
    true
  end
end