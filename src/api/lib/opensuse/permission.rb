# require "project"
# require "package"

#
# This is basically only a helper class around permission checking for user model
#

module Suse
  class Permission
    def to_s
      "OpenSUSE Permissions for user #{@user.login}"
    end

    def initialize( u )
      @user = u
      logger.debug "User #{@user.login} initialised"
    end

    def project_change?( project = nil )
      # one is project admin if he has the permission Project_Admin or if he
      # is the owner of the project
      logger.debug "User #{@user.login} wants to change the project"

      if project.kind_of? Project
        prj = project
      elsif project.kind_of? String
        prj = Project.find_by_name( project )
        # avoid remote projects
        return false unless prj.kind_of? Project
      end

      raise ArgumentError, "unable to find project object for #{project}" if prj.nil?

      return true if @user.has_global_permission?( "global_project_change" )

      @user.can_modify_project?( prj )
    end

    # args can either be an instance of the respective class (Package, Project),
    # the database object or package/project names.
    #
    # the second arg can be omitted if the first one is a Package object. second
    # arg is needed if first arg is a string

    def package_change?( package, project = nil )
      logger.debug "User #{@user.login} wants to change the package"

      # Get DbPackage object
      if package.kind_of? Package
        pkg = package
      else
        if project.nil?
          raise RuntimeError, "autofetch of project only works with objects of class Package"
        end

        if project.kind_of? String
           project = project
        end

        pkg = Package.find_by_project_and_name( project, package )
        if pkg.nil?
          raise ArgumentError, "unable to find package object for #{project} / #{package}"
        end
      end

      return true if @user.can_modify_package?( pkg )
      false
    end

    def method_missing( perm, *_args, &_block)
      logger.debug "Dynamic Permission requested: <#{perm}>"

      if @user
        if @user.has_global_permission? perm.to_s
          logger.debug "User #{@user.login} has permission #{perm}"
          return true
        else
          logger.debug "User #{@user.login} does NOT have permission #{perm}"
          return false
        end
      else
        logger.debug "Permission check failed because no user is checked in"
        return false
      end
    end

    def logger
      Rails.logger
    end
  end
end
