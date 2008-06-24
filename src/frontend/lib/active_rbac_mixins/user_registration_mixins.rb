module ActiveRbacMixins
  # The UserRegistrationMixin module provides the functionality for the 
  # UserRegistration  ActiveRecord class. You can use it the following way: 
  # Create a file "model/user_registration.rb" in your "RAILS_ENV/app" 
  # directory.
  #
  # Here, create the UserRegistration class and import the UserRegistration mixin
  # module, e.g.:
  #
  #   class UserRegistration < ActiveRecord::Base
  #     include ActiveRbacMixins::UserRegistrationMixins::Core
  #
  #     # insert your custom code here
  #   end
  #
  # This will create a ActiveRecord class you can then extend to your liking (i.e.
  # just imagine you had written all the stuff that ActiveRbac's UserRegistration
  # class provides and you can now write some custom lines below it).
  module UserRegistrationMixins
    module Core
      # This method is called when the module is included.
      #
      # On inclusion, we do a nifty bit of meta programming and make the
      # including class behave like ActiveRBAC's StaticPermission class.
      def self.included(base)
        base.class_eval do
          # user_registrations have a n:1 relation to users
          belongs_to :user

          # Initialize sets the expires_at and token property. Thus we need no 
          # validation since everything is set automatically anyway.
          def initialize(arguments=nil)
            super(arguments)

            self.expires_at = Time.now + (60 * 60 * 24)
            self.token = Digest::MD5.hexdigest(expires_at.to_s + '--' + rand.to_s).slice(1,10)
          end

          # Returns true if this token has expired.
          def expired?
            expires_at > Time.now
          end

          # We only need to validate the token here.
          validates_format_of     :token, 
                                  :with => %r{^[\w]*$}, 
                                  :message => 'must not contain invalid characters.'
          validates_length_of     :token, 
                                  :is => 10,
                                  :too_long => 'must have exactly 10 characters.'
        end
      end
    end
  end
end