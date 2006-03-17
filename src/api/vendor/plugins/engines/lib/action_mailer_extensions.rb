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

# Overriding ActionMailer to teach it about Engines...
module ActionMailer
  class Base

    # Initialize the mailer via the given +method_name+. The body will be
    # rendered and a new TMail::Mail object created.
    def create!(method_name, *parameters) #:nodoc:
      initialize_defaults(method_name)
      send(method_name, *parameters)


      # If an explicit, textual body has not been set, we check assumptions.
      unless String === @body
        # First, we look to see if there are any likely templates that match,
        # which include the content-type in their file name (i.e.,
        # "the_template_file.text.html.rhtml", etc.). Only do this if parts
        # have not already been specified manually.

        templates = get_all_templates_for_action(@template)
        
        #RAILS_DEFAULT_LOGGER.debug "template: #{@template}; templates: #{templates.inspect}"

        if @parts.empty?
          
          # /app/views/<mailer object name> / <action>.something.rhtml
          
          #templates = Dir.glob("#{template_path}/#{@template}.*")
                    
          # this loop expects an array of paths to actual template files which match
          # the given action name
          templates.each do |path|
            type = (File.basename(path).split(".")[1..-2] || []).join("/")
            #RAILS_DEFAULT_LOGGER.debug "type: #{type}"
            next if type.empty?
            #RAILS_DEFAULT_LOGGER.debug "other bit: #{File.basename(path).split(".")[0..-2].join('.')}"
            @parts << Part.new(:content_type => type,
              :disposition => "inline", :charset => charset,
              :body => render_message(File.basename(path).split(".")[0..-2].join('.'), @body))
          end
          unless @parts.empty?
            @content_type = "multipart/alternative"
            @charset = nil
            @parts = sort_parts(@parts, @implicit_parts_order)
          end
        end

        # Then, if there were such templates, we check to see if we ought to
        # also render a "normal" template (without the content type). If a
        # normal template exists (or if there were no implicit parts) we render
        # it.
        template_exists = @parts.empty?
        #template_exists ||= Dir.glob("#{template_path}/#{@template}.*").any? { |i| i.split(".").length == 2 }
        template_exists ||= templates.any? { |i| File.basename(i).split(".").length == 2 }
        #RAILS_DEFAULT_LOGGER.debug "template_exists? #{template_exists}"
        @body = render_message(@template, @body) if template_exists

        # Finally, if there are other message parts and a textual body exists,
        # we shift it onto the front of the parts and set the body to nil (so
        # that create_mail doesn't try to render it in addition to the parts).
        if !@parts.empty? && String === @body
          @parts.unshift Part.new(:charset => charset, :body => @body)
          @body = nil
        end
      end

      # If this is a multipart e-mail add the mime_version if it is not
      # already set.
      @mime_version ||= "1.0" if !@parts.empty?

      # build the mail object itself
      @mail = create_mail
    end

    private


      # JGA - Modified to pass the method name to initialize_template_class
      def render(opts)
        body = opts.delete(:body)
        initialize_template_class(body, opts[:file]).render(opts)
      end

      
      # Return all ActionView template paths from the app and all Engines
      def template_paths
        paths = [template_path]
        Engines.active.each { |engine|
          # add a path for every engine if one exists.
          engine_template_path = File.join(engine.root, "app", "views", mailer_name)
          paths << engine_template_path if File.exists?(engine_template_path)
        }
        paths
      end

      # Returns a list of all template paths in the app and Engines
      # which contain templates that might be used for the given action
      def get_all_templates_for_action(action)
        # can we trust uniq! to do this? i'm not sure...
        templates = []
        seen_names = []
        template_paths.each { |path|
          all_templates_for_path = Dir.glob(File.join(path, "#{action}.*"))
          all_templates_for_path.each { |template|
            name = File.basename(template)
            if !seen_names.include?(name)
              seen_names << name
              templates << template
            end
          }
        }
        templates
      end

      # Returns the first path to the given template in our
      # app/Engine 'chain'.
      def find_template_root_for(template)
        all_paths = get_all_templates_for_action(template)
        if all_paths.empty?
          return template_path
        else
          return File.dirname(all_paths[0])
        end
      end

      # JGA - changed here to include the method name that we
      # are interested in, so that we can re-locate the proper
      # template root
      def initialize_template_class(assigns, method_name)
        engine_template = find_template_root_for(method_name)
        #ActionView::Base.new(engine_template, assigns, self)
        action_view_class = Class.new(ActionView::Base).send(:include, master_helper_module)
        action_view_class.new(engine_template, assigns, self)        
      end


  end
end
