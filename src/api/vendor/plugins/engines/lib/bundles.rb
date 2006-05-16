require 'bundles/require_resource'

# The 'require_bundle' method is used in views to declare that certain stylesheets and javascripts should
# be included by the 'resource_tags' (used in the layout) for the view to function properly.
module Bundles
  def require_bundle(name, *args)
    method = "bundle_#{name}"
    send(method, *args)
  end
  
  def require_bundles(*names)
    names.each { |name| require_bundle(name) }
  end
end

ActionView::Base.send(:include, Bundles)

# Registers a module within the Bundles module by renaming the module's 'bundle' method (so it doesn't
# clash with other methods named 'bundle') and by including any Controller or Helper modules within
# their respective Rails base classes.
#
# For example, if you have a module such as
#   module Bundles::Calendar; end
#
# then within that Calendar module there *must* be a method named "bundle" which groups the
# bundle's resources together.  Example:
#   module Bundles::Calendar
#     def bundle
#       require_relative_to Engines.current.public_dir do
#         require_stylesheet "/stylesheets/calendar.css"
#         require_javascript "/javascripts/calendar.js"
#       end
#     end
#   end
#
# You may optionally define a Controller or Helper sub-module if you need any methods available to
# the applications controllers or views.  Example:
#
#   module Bundles::Calendar
#     module Helper
#       def calendar_date_select(*args
#         # ... output some HTML
#       end
#     end
#   end
#
# The calendar_date_select method will now be available within the scope of the app's views because the
# register_bundle method will inject the Helper module's methods in to ActionView::Base for you.
#
# Similarly, you can make methods available to controllers by adding a Controller module.
def register_bundle(name)
  require "bundles/#{name}"
  
  # Rename the generic 'bundle' method in to something that doesn't conflict with
  # the other module method names.
  bundle_module = Bundles.const_get(name.to_s.camelize)
  bundle_module.module_eval "alias bundle_#{name} bundle"
  bundle_module.send :undef_method, :bundle

  # Then include the bundle module in to the base module, so that the methods will
  # be available inside ActionView::Base
  ActionView::Base.send(:include, bundle_module)

  # Check for optional Controller module
  if bundle_module.const_defined? 'Controller'
    controller_addon = bundle_module.const_get('Controller')
    RAILS_DEFAULT_LOGGER.debug "Including #{name} bundle's Controller module"
    ActionController::Base.send(:include, controller_addon)
  end

  # Check for optional Helper module
  if bundle_module.const_defined? 'Helper'
    helper_addon = bundle_module.const_get('Helper')
    RAILS_DEFAULT_LOGGER.debug "Including #{name} bundle's Helper module"
    ActionView::Base.send(:include, helper_addon)
  end
end