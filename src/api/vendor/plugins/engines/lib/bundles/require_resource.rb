# RequireResource v.1.4 by Duane Johnson
#
# Makes inclusion of javascript and stylesheet resources easier via automatic or explicit
# calls.  e.g. require_javascript 'popup' is an explicit call.
#
# The simplest way to make use of this functionality is to add
#   <%= resource_tags %>
# to your layout (usually in the <head></head> section).  This will automatically add
# bundle support to your application, as well as enable simple javascript and stylesheet
# dependencies for your views.
#
# Note that this can easily be turned in to a helper on its own.
module RequireResource
  mattr_accessor :path_prefix

  # Write out all javascripts & stylesheets, including default javascripts (unless :defaults => false)
  def resource_tags(options = {})
    options = {:auto => true, :defaults => true}.update(options)
    require_defaults if options[:defaults]
    stylesheet_auto_link_tags(:auto => options[:auto]) +
    javascript_auto_include_tags(:auto => options[:auto])
  end
  
  # Write out the <link> tags themselves based on the array of stylesheets to be included
  def stylesheet_auto_link_tags(options = {})
    options = {:auto => true}.update(options)
    ensure_resource_is_initialized(:stylesheet)
    autorequire(:stylesheet) if options[:auto]
    @stylesheets.uniq.inject("") do |buffer, css|
      buffer << stylesheet_link_tag(css) + "\n    "
    end
  end

  # Write out the <script> tags themselves based on the array of javascripts to be included
  def javascript_auto_include_tags(options = {})
    options = {:auto => true}.update(options)
    ensure_resource_is_initialized(:javascript)
    autorequire(:javascript) if options[:auto]
    @javascripts.uniq.inject("") do |buffer, js|
      buffer << javascript_include_tag(js) + "\n    "
    end
  end

  # Bundle the defaults together for easy inclusion
  def require_defaults
    require_javascript(:prototype)
    require_javascript(:controls)
    require_javascript(:effects)
    require_javascript(:dragdrop)
  end
  
  # Adds a javascript to the array of javascripts that will be included in the layout by
  # either your call to 'javascript_auto_include_tags' or 'resource_tags'.
  def require_javascript(*scripts)
    scripts.each do |script|
      require_resource(:javascript, RequireResource.path_prefix.to_s + script.to_s)
    end
  end

  # Adds a stylesheet to the array of stylesheets that will be included in the layout by
  # either your call to 'stylesheet_auto_link_tags' or 'resource_tags'.
  def require_stylesheet(*sheets)
    sheets.each do |sheet|
      require_resource(:stylesheet, RequireResource.path_prefix.to_s + sheet.to_s)
    end
  end
  
  # Changes the RequireResource.path_prefix within the scope of a block.  This is
  # particularly useful when requiring several resources within a directory.  For example,
  # bundles can take advantage of this by calling
  #   require_relative_to Engines.current.public_dir do
  #     require_javascript '...'
  #     require_stylesheet '...'
  #     # ...
  #   end
  def require_relative_to(path)
    former_prefix = RequireResource.path_prefix
    RequireResource.path_prefix = path
    yield
    RequireResource.path_prefix = former_prefix
  end
  
  protected
    # Adds resources such as stylesheet or javascript files to the corresponding array of
    # resources that will be 'required' by the layout. The +resource_type+ is either
    # :javascript or :stylesheet. The +extension+ is optional, and should normally correspond
    # with the resource type, e.g. 'css' for :stylesheet and 'js' for :javascript.
    def autorequire(resource_type, extension = nil)
      extensions = {:stylesheet => 'css', :javascript => 'js'}
      extension ||= extensions[resource_type]
      candidates = []
      class_iterator = controller.class
      resource_path = "#{RAILS_ROOT}/public/#{resource_type.to_s.pluralize}/" 

      while ![ActionController::Base].include? class_iterator
        controller_path = class_iterator.to_s.underscore.sub('controllers/', '').sub('_controller', '')
        candidates |= [ "#{controller_path}", "#{controller_path}/#{controller.action_name}" ]
        class_iterator = class_iterator.superclass
      end
      
      for candidate in candidates
        if FileTest.exist?("#{resource_path}/#{candidate}.#{extension}")
          require_resource(resource_type, candidate)
        end
      end
    end

    # Adds a resource (e.g. a javascript) to the appropriate array (e.g. @javascripts)
    # ONLY if the resource is not already included.
    def require_resource(type, name)
      variable = type.to_s.pluralize
      new_resource_array = (instance_variable_get("@#{variable}") || []) | [name.to_s]
      instance_variable_set("@#{variable}", new_resource_array)
    end

    # Ensures that a resource array (e.g. @javascripts) is not nil--uses [] if so
    def ensure_resource_is_initialized(type)
      variable = type.to_s.pluralize
      new_resource_array = (instance_variable_get("@#{variable}") || [])
      instance_variable_set("@#{variable}", new_resource_array)      
    end
end

ActionView::Base.send(:include, RequireResource)
