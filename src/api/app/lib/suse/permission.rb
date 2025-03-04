# require "project"
# require "package"

#
# This is basically only a helper class around permission checking for user model
#

module Suse
  class Permission
    def to_s
      "openSUSE Permissions for user #{@user.login}"
    end

    def initialize(u)
      @user = u
      logger.debug "User #{@user.login} initialised"
    end

    def project_change?(project = nil)
      # one is project admin if they have the permission Project_Admin or if they
      # are the owner of the project
      logger.debug "User #{@user.login} wants to change the project"

      case project
      when Project
        prj = project
      when String
        prj = Project.find_by_name(project)
        # avoid remote projects
        return false unless prj.is_a?(Project)
      end

      raise ArgumentError, "unable to find project object for #{project}" if prj.nil?

      return true if @user.global_permission?('global_project_change')

      @user.can_modify?(prj)
    end

    # args can either be an instance of the respective class (Package, Project),
    # the database object or package/project names.
    #
    # the second arg can be omitted if the first one is a Package object. second
    # arg is needed if first arg is a string

    def package_change?(package, project = nil)
      logger.debug "User #{@user.login} wants to change the package"

      # Get DbPackage object
      if package.is_a?(Package)
        pkg = package
      else
        raise 'autofetch of project only works with objects of class Package' if project.nil?

        pkg = Package.find_by_project_and_name(project, package)
        raise ArgumentError, "unable to find package object for #{project} / #{package}" if pkg.nil?
      end

      return true if @user.can_modify?(pkg)

      false
    end

    def method_missing(perm, *_args, &)
      logger.debug "Dynamic Permission requested: <#{perm}>"

      if @user
        if @user.global_permission?(perm.to_s)
          logger.debug "User #{@user.login} has permission #{perm}"
          true
        else
          logger.debug "User #{@user.login} does NOT have permission #{perm}"
          false
        end
      else
        logger.debug 'Permission check failed because no user is checked in'
        false
      end
    end

    delegate :logger, to: :Rails
  end
end
