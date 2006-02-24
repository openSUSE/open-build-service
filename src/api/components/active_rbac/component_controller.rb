require_dependency 'active_rbac/configuration'

# All controllers in ActiveRBAC extend this controller. Currently, it only
# provides the method config to access ActiveRBAC's configuration.
class ActiveRbac::ComponentController < ApplicationController
  
  protected
  
    # This method returns the config class. See this
    # class' documentation about the details of the various configuration
    # options.
    #
    # Example:
    #
    # class ActiveRbac::GroupController < ActiveRbac::ComponentController
    #   layout config.controller[:layout]
    # end
    def self.config
      ActiveRbac::Configuration
    end
    
    # An alias to self.config
    def config; self.class.config; end
end