#--
# Copyright (c) 2004 David Heinemeier Hansson

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Engine Hacks by James Adam, 2005.
#++

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
        Engines.active.each do |engine|
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