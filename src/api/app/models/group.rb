# The Group class represents a group record in the database and thus a group
# in the ActiveRbac model. Groups are arranged in trees and have a title.
# Groups have an arbitrary number of roles and users assigned to them.
#
# The Group ActiveRecord class mixes in the "ActiveRbacMixins::GroupMixins::*" modules.
# These modules contain the actual implementation. It is kept there so
# you can easily provide your own model files without having to all lines
# from the engine's directory
#
class Group < ActiveRecord::Base
  include ActiveRbacMixins::GroupMixins::Validation
  include ActiveRbacMixins::GroupMixins::Core

  has_many :groups_users, :foreign_key => 'group_id'
  has_many :project_group_role_relationships, :foreign_key => 'bs_group_id'
  has_many :package_group_role_relationships, :foreign_key => 'bs_group_id'

  class << self
    def render_group_list(user=nil)
       builder = Builder::XmlMarkup.new( :indent => 2 )
       xml = ""

       if user
         user = User.find_by_login(user)
         return nil if user.nil?
         if User.ldapgroup_enabled?
           begin
             list = User.render_grouplist_ldap(Group.find(:all), user.login)
           rescue Exception
             logger.debug "Error occurred in rendering grouplist in ldap."
           end
         else
           list = user.groups
         end
       else
         if User.ldapgroup_enabled?
           begin
             list = User.render_grouplist_ldap(Group.find(:all))
           rescue Exception
             logger.debug "Error occurred in rendering grouplist in ldap."
           end
         else
           list = Group.find(:all)
         end
       end

       xml = builder.directory( :count => list.length ) do |dir|
         list.each do |g|
           dir.entry( :name => g.title )
         end
       end

       return xml
    end

    def get_by_title(title)
      g = find :first, :conditions => ["title = BINARY ?", title]
      raise GroupNotFoundError.new( "Error: Group '#{title}' not found." ) unless g
      return g
    end
  end

  def render_axml
    builder = Builder::XmlMarkup.new(:indent => 2)
    logger.debug "----------------- rendering group #{self.title} ------------------------"
    xml = builder.group() do |group|
      group.title(self.title)
    end
    xml
  end

  def involved_projects_ids
    # just for maintainer for now.
    role = Role.find_by_title "maintainer"

    ### all projects where group is maintainer
    # ur is the target user role relationship
    sql =
    "SELECT prj.id
    FROM db_projects prj
    LEFT JOIN project_group_role_relationships ur ON prj.id = ur.db_project_id
    WHERE ur.bs_group_id = #{id} and ur.role_id = #{role.id}"
    projects = ActiveRecord::Base.connection.select_values sql

    projects += ActiveRecord::Base.connection.select_values sql
    projects.uniq.map {|p| p.to_i }
  end
  protected :involved_projects_ids
  
  def involved_projects
    projects = involved_projects_ids
    return [] if projects.empty?
    # now filter the projects that are not visible
    return DbProject.find_by_sql("SELECT distinct prj.* FROM db_projects prj 
                                  LEFT JOIN flags f on f.db_project_id = prj.id
                                  LEFT JOIN project_group_role_relationships aur ON aur.db_project_id = prj.id
                                  where prj.id in (#{projects.join(',')})
                                  and (f.flag is null or f.flag != 'access' or aur.id = #{User.currentID})")
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    # just for maintainer for now.
    role = Role.find_by_title "maintainer"

    projects = involved_projects_ids
    projects << -1 if projects.empty?

    # all packages where group is maintainer
    sql =<<-END_SQL
    SELECT pkg.id
    FROM db_packages pkg
    LEFT JOIN db_projects prj ON prj.id = pkg.db_project_id
    LEFT JOIN package_group_role_relationships ur ON pkg.id = ur.db_package_id
    WHERE ur.bs_user_id = #{id} and ur.role_id = #{role.id} and
    prj.id not in (#{projects.join(',')})
    END_SQL
    packages = ActiveRecord::Base.connection.select_values sql

    return [] if packages.empty?
    return DbPackage.find_by_sql("SELECT distinct pkg.* FROM db_packages pkg
                                  LEFT JOIN flags f on f.db_project_id = pkg.db_project_id
                                  LEFT JOIN project_user_role_relationships aur ON aur.db_project_id = pkg.db_project_id
                                  where pkg.id in (#{packages.join(',')})
                                  and (f.flag is null or f.flag != 'access' or aur.id = #{User.currentID})")
 
  end
end
