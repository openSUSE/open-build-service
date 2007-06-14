module ActiveRbacMixins
  # The StaticPermissionMixin module provides the functionality for the 
  # StaticPermission ActiveRecord class. You can use it the following way: 
  # Create a file "model/static_permission.rb" in your "RAILS_ENV/app" 
  # directory.
  #
  # Here, create the StaticPermission class and import the StaticPermission mixin modules, 
  # e.g.:
  #
  #   class StaticPermission < ActiveRecord::Base
  #     include ActiveRbacMixins::StaticPermissionMixins
  #
  #     # insert your custom code here
  #   end
  #
  # This will create a ActiveRecord class you can then extend to your liking (i.e.
  # just imagine you had written all the stuff that ActiveRbac's StaticPermission
  # class provides and you can now write some custom lines below it).
  module StaticPermissionMixins
    module Core
      # This method is called when the module is included.
      #
      # On inclusion, we do a nifty bit of meta programming and make the
      # including class behave like ActiveRBAC's StaticPermission class
      # without some of the validation. Extensive validation can be
      # done with Validation module.
      def self.included(base)
        base.class_eval do
          # static permissions have n:m relations to roles
          has_and_belongs_to_many :roles, :uniq => true

          # This method returns all roles this permission has been granted 
          # to and all of their children.
          def all_roles
            result = []

            self.roles.each { |role| result << role.descendants_and_self }

            result.flatten!
            result.uniq!

            return result
          end

          # We want to validate a static permission's title pretty thoroughly.
          validates_uniqueness_of :title, 
                                  :message => 'is the name of an already existing static permission.'
          validates_presence_of   :title, 
                                  :message => 'must be given.'
        end
      end
    end
    
    module Validation
      # This method is called when the module is included.
      #
      # On inclusion, we do a nifty bit of meta programming and make the
      # including class do the default validation of ActiveRBAC's 
      # StaticPermission class.
      def self.included(base)
        base.class_eval do
          validates_format_of     :title, 
                                  :with => %r{^[\w \$\^\-\.#\*\+&'"]*$}, 
                                  :message => 'must not contain invalid characters.'
          validates_length_of     :title, 
                                  :in => 2..100, :allow_nil => true,
                                  :too_long => 'must have less than 100 characters.', 
                                  :too_short => 'must have more than two characters.'
        end
      end
    end
  end
end