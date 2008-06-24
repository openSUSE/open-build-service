module ActiveRbacMixins
  # Mix this module into your ApplicationController to get the "current_user" 
  # method which returns the User instance of the currently logged in user.
  module ApplicationControllerMixin
    def self.included(base)
      base.class_eval do
        protected

          def current_user
            return @active_rbac_user unless @active_rbac_user.nil?
    
            @active_rbac_user = 
                    if session[:rbac_user_id].nil? then
                      ::AnonymousUser.instance
                    else
                      ::User.find(session[:rbac_user_id])
                    end
    
            return @active_rbac_user
          end
      end
    end
  end
end
