
module Suse
require 'components/active_rbac/helpers/rbac_helper'

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
      
      if @user.has_permission( 'global_package_create' )
        return true
      else
	val = project_maintainers project
	logger.debug "Project-Maintainers: #{val}"
	if val and val.find{ |u| u == @user.login }
	  return true 
	end
      end
      return false	
    end
    
    # One may change a package if he either has the global_package_change
    # permission or if he is maintainer of the project 
    # TODO: or if he is maintainer of the package
    def package_change?( project = nil, package = nil )
      logger.debug "User #{@user.login} wants to change the package"
      
      if @user.has_permission( "global_package_change" )
        return true
      else
	val = project_maintainers project
	if val.find{ |u| u == @user.login }
	  return true
	end
      end
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

    def project_maintainers( project )
      val = []
      path = "/source/#{project}/_meta"
      
      response = Suse::Backend.get( path )
      
      doc = REXML::Document.new( response.body )
      logger.debug "The XML Document: " + doc.to_s
      root = doc.root

      doc.elements.each("project/person[@role='maintainer']") { |elem| val << elem.attributes["userid"] }

      logger.debug "returning values: #{val}"
      return val
    end

    
    def logger
      RAILS_DEFAULT_LOGGER
    end
  end
end
