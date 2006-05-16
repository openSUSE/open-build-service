require 'fileutils'

module ::ActionView
  class Base
    private
      def full_template_path(template_path, extension)

        # If the template exists in the normal application directory,
        # return that path
        default_template = "#{@base_path}/#{template_path}.#{extension}"
        return default_template if File.exist?(default_template)

        # Otherwise, check in the engines to see if the template can be found there.
        # Load this in order so that more recently started Engines will take priority.
        Engines.each(:precidence_order) do |engine|
          site_specific_path = File.join(engine.root, 'app', 'views',  template_path.to_s + '.' + extension.to_s)
          return site_specific_path if File.exist?(site_specific_path)
        end

        # If it cannot be found anywhere, return the default path, where the
        # user *should* have put it.  
        return "#{@base_path}/#{template_path}.#{extension}" 
      end
  end


  # add methods to handle including javascripts and stylesheets
  module Helpers
    module AssetTagHelper
      # Returns a stylesheet link tag to the named stylesheet(s) for the given
      # engine. A stylesheet with the same name as the engine is included automatically.
      # If other names are supplied, those stylesheets from within the same engine
      # will be linked too.
      #
      #   engine_stylesheet "my_engine" =>
      #   <link href="/engine_files/my_engine/stylesheets/my_engine.css" media="screen" rel="Stylesheet" type="text/css" />
      #
      #   engine_stylesheet "my_engine", "another_file", "one_more" =>
      #   <link href="/engine_files/my_engine/stylesheets/my_engine.css" media="screen" rel="Stylesheet" type="text/css" />
      #   <link href="/engine_files/my_engine/stylesheets/another_file.css" media="screen" rel="Stylesheet" type="text/css" />
      #   <link href="/engine_files/my_engine/stylesheets/one_more.css" media="screen" rel="Stylesheet" type="text/css" />
      #
      # Any options supplied as a Hash as the last argument will be processed as in
      # stylesheet_link_tag.
      #
      def engine_stylesheet(engine_name, *sources)
        stylesheet_link_tag(*convert_public_sources(engine_name, :stylesheet, sources))
      end

      # Returns a javascript link tag to the named stylesheet(s) for the given
      # engine. A javascript file with the same name as the engine is included automatically.
      # If other names are supplied, those javascript from within the same engine
      # will be linked too.
      #
      #   engine_javascript "my_engine" =>
      #   <script type="text/javascript" src="/engine_files/my_engine/javascripts/my_engine.js"></script>
      #
      #   engine_javascript "my_engine", "another_file", "one_more" =>
      #   <script type="text/javascript" src="/engine_files/my_engine/javascripts/my_engine.js"></script>
      #   <script type="text/javascript" src="/engine_files/my_engine/javascripts/another_file.js"></script>
      #   <script type="text/javascript" src="/engine_files/my_engine/javascripts/one_more.js"></script>
      #
      # Any options supplied as a Hash as the last argument will be processed as in
      # javascript_include_tag.
      #
      def engine_javascript(engine_name, *sources)
        javascript_include_tag(*convert_public_sources(engine_name, :javascript, sources))       
      end

      # Returns a image tag based on the parameters passed to it
      # Required option is option[:engine] in order to correctly idenfity the correct engine location
      #
      #   engine_image 'rails-engines.png', :engine => 'my_engine', :alt => 'My Engine' =>
      #   <img src="/engine_files/my_engine/images/rails-engines.png" alt="My Engine />
      #
      # Any options supplied as a Hash as the last argument will be processed as in
      # image_tag.
      #
      def engine_image(src, options = {})
      	return if !src

      	image_src = engine_image_src(src, options)

      	options.delete(:engine)

      	image_tag(image_src, options)
      end

      # Alias for engine_image
      def engine_image_tag(src, options = {})
        engine_image(src, options)
      end

      # Returns a path to the image stored within the engine_files
      # Required option is option[:engine] in order to correctly idenfity the correct engine location
      #
      #   engine_image_src 'rails-engines.png', :engine => 'my_engine' =>
      #   "/engine_files/my_engine/images/rails-engines.png"
      #
      def engine_image_src(src, options = {})
        File.join(Engines.get(options[:engine].to_sym).public_dir, 'images', src)
      end
      
      private
        # convert the engine public file sources into actual public paths
        # type:
        #   :stylesheet
        #   :javascript
        def convert_public_sources(engine_name, type, sources)
          options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }
          new_sources = []
        
          case type
            when :javascript
              type_dir = "javascripts"
              ext = "js"
            when :stylesheet
              type_dir = "stylesheets"
              ext = "css"
          end
          
          engine = Engines.get(engine_name)
          
          default = "#{engine.public_dir}/#{type_dir}/#{engine_name}"
          if defined?(RAILS_ROOT) && File.exists?(File.join(RAILS_ROOT, "public", "#{default}.#{ext}"))
            new_sources << default
          end
        
          sources.each { |name| 
            new_sources << "#{engine.public_dir}/#{type_dir}/#{name}"
          }

          new_sources << options         
        end
    end
  end
end
