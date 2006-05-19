require "project"
require "package"


module Suse

  class Permission
  
    def to_s
      return "OpenSUSE Permissions for user #{@user.login}"
    end
    
    def initialize( u )
      @user = u
      logger.debug "User #{@user.login} initialised"
    end
    
    def project_change?( project = nil )
       # one is project admin if he has the permission Project_Admin or if he
       # is the owner of the project
       logger.debug "User #{@user.login} wants to change the project"

       if @user.has_permission( "global_project_change" )
         return true
       else
         val = project_maintainers project

         if val and val.find{ |u| u == @user.login }
	   logger.debug "Returning true from project_change?"
	   return true
         end
	   logger.debug "Returning false from project_change?"
	   return false
       end
    end
    
    # One may create a package if he either has the global_package_create
    # permission or if he is maintainer of the project.
    def package_create?( project )
      logger.debug "User #{@user.login} wants to create a package in #{project}"
      
      return true if @user.has_permission( 'global_package_create' )
	
      valid_users = project_maintainers project
      return true if valid_users
      if val and val.find{ |u| u == @user.login }
	  return true 
	end
      end
      return false	
    end
    
    # One may change a package if he either has the global_package_change
    # permission or if he is maintainer of the project or maintainer of the
    # package
    #
    # args can either be an instance of the respective class (Package, Project)
    # or package/project names.
    #
    # the second arg can be omitted if the first one is a Package object. second
    # arg is needed if first arg is a string

    def package_change?( package, project=nil )
      logger.debug "User #{@user.login} wants to change the package"
     
      return true if @user.has_permission( "global_package_change" )

      #check if current user is mentioned in the package meta file
      valid_users = package_maintainers( package, project )
      return true if valid_users.include? @user.login

      #try to find parent project of package if it is not set
      if project.nil?
        if not package.kind_of? Package
          raise "autofetch of project only works with objects of class Package"
        end

        if package.parent_project_name.nil?
          raise "unable to determine parent project for package #{package}"
        end

        project = package.parent_project
      end

      # check if current user is mentioned in the project meta file
      valid_users = project_maintainers( project )
      return true if valid_users.include? @user.login
        
      return false
    end
    
    def method_missing( perm, *args, &block)
  
      logger.debug "Dynamic Permission requested: <#{perm}>"
	
      if @user 
	if @user.has_permission perm.to_s
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

    # returns the package maintainers as a list of login names
    # argument can be a instance of the Project class or a project name
    def project_maintainers( project )
      val = Array.new

      if( project.kind_of? Project )
        p = project
      else
        p = Project.find project
      end

      p.each_person do |person| 
        if person.role == "maintainer" or person.role == "owner"
          val << person.userid
        end
      end

      logger.debug "returning project maintainers: #{val}"
      return val
    end

    # returns the package maintainers as a list of login names
    # argument can be an instance of the Package class or a package name
    # if first arg is a package name, the name of the packages project has to be
    # given as second arg
    def package_maintainers( package, project=nil )
      val = Array.new
      
      if( package.kind_of? Package )
        p = package
      elsif project.nil?
        raise "Permission#package_maintainers: project name must be given if first parameter is no Package object"
      else
        p = Package.find package, :project => project
      end

      p.each_person do |person| 
        if person.role == "maintainer" or person.role == "owner"
          val << person.userid
        end
      end
      logger.debug "returning package maintainers: #{val}"
      return val
    end

    def logger
      RAILS_DEFAULT_LOGGER
    end
  end
end
