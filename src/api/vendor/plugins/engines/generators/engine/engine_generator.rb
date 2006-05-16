#  Copyright (c) 2005 Jonathan Lim <snowblink@gmail.com>
#  
#  The MIT License
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.


module Rails
  module Generator
    module Commands

      class Create < Base
        def complex_template(relative_source, relative_destination, template_options = {})
          options = template_options.dup
          options[:assigns] ||= {}
          options[:assigns]['template_for_inclusion'] = render_template_part(template_options) if template_options[:mark_id]
          options[:assigns]['license'] = render_license(template_options)
          template(relative_source, relative_destination, options)
        end

        def render_license(template_options)
          # Getting Sandbox to evaluate part template in it
          part_binding = template_options[:sandbox].call.sandbox_binding
          part_rel_path = template_options[:insert]
          part_path = source_path(part_rel_path)

          # Render inner template within Sandbox binding
          template_file = File.readlines(part_path)
          case template_options[:comment_style]
          when :rb
            template_file.map! {|x| x.sub(/^/, '#  ')}
          end
          rendered_part = ERB.new(template_file.join, nil, '-').result(part_binding)
        end

      end
    end
  end
end


class LicensingSandbox
  include ActionView::Helpers::ActiveRecordHelper
  attr_accessor :author

  def sandbox_binding
    binding
  end

end

class Author
  def initialize
    set_name
    set_email
  end

  def set_name
    print "Please enter the author's name: "
    @name = gets.chomp
  end

  def set_email
    print "Please enter the author's email: "
    @email = gets.chomp
  end

  def to_s
    "#{@name} <#{@email}>"
  end
end

class License
  def initialize(source_root)
    @source_root = source_root
    select_license
  end

  def select_license
    # list all the licenses in the licenses directory
    licenses = Dir.entries(File.join(@source_root, 'licenses')).select { |name| name !~ /^\./ }
    puts "We can generate the following licenses automatically for you:"
    licenses.sort.each_with_index do |license, index|
      puts "#{index}) #{licenses[index]}"
    end
    print "Please select a license: "
    while choice = gets.chomp
      if (choice !~ /^[0-9]+$/)
        print "Hint - you want to be typing a number.\nPlease select a license: "
        next
      end
      break if choice.to_i >=0 && choice.to_i <= licenses.length
    end
      
    @license = licenses[choice.to_i]
    puts "'#{@license}' selected"
  end

  def to_s
    File.join('licenses', @license)
  end

end

class EngineGenerator < Rails::Generator::NamedBase

  attr_reader :engine_class_name, :engine_underscored_name, :engine_start_name, :author


  def initialize(runtime_args, runtime_options = {})
    super
    @engine_class_name = runtime_args.shift
    
    # ensure that they've given us a valid class name
    if @engine_class_name =~ /^[a-z]/
      raise "'#{@engine_class_name}' should be a valid Ruby constant, e.g. 'MyEngine'; aborting generation..." 
    end
    
    @engine_underscored_name = @engine_class_name.underscore
    @engine_start_name = @engine_underscored_name.sub(/_engine$/, '')
    @author = Author.new
    @license = License.new(source_root)
  end

  def manifest
    record do |m|
      m.directory File.join('vendor', 'plugins')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name)
      m.complex_template 'README',
        File.join('vendor', 'plugins', @engine_underscored_name, 'README'),
        :sandbox => lambda {create_sandbox},
        :insert => @license.to_s

      m.file 'install.erb', File.join('vendor', 'plugins', @engine_underscored_name, 'install.rb')
      
      m.complex_template 'init_engine.erb',
        File.join('vendor', 'plugins', @engine_underscored_name, 'init_engine.rb'),
        :sandbox => lambda {create_sandbox},
        :insert => @license.to_s,
        :comment_style => :rb

      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'app')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'app', 'models')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'app', 'controllers')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'app', 'helpers')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'app', 'views')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'db')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'db', 'migrate')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'lib')
      m.complex_template File.join('lib', 'engine.erb'),
        File.join('vendor', 'plugins', @engine_underscored_name, 'lib', "#{@engine_underscored_name}.rb"),
        :sandbox => lambda {create_sandbox},
        :insert => @license.to_s,
        :comment_style => :rb

      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'lib', @engine_underscored_name)
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'public')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'public', 'javascripts')
      m.template File.join('public', 'javascripts', 'engine.js'), File.join('vendor', 'plugins', @engine_underscored_name, 'public', 'javascripts', "#{@engine_underscored_name}.js")
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'public', 'stylesheets')
      m.template File.join('public', 'stylesheets', 'engine.css'), File.join('vendor', 'plugins', @engine_underscored_name, 'public', 'stylesheets', "#{@engine_underscored_name}.css")
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'tasks')
      m.template File.join('tasks', 'engine.rake'), File.join('vendor', 'plugins', @engine_underscored_name, 'tasks', "#{@engine_underscored_name}.rake")
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'test')
      m.template File.join('test', 'test_helper.erb'), File.join('vendor', 'plugins', @engine_underscored_name, 'test', 'test_helper.rb')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'test', 'fixtures')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'test', 'functional')
      m.directory File.join('vendor', 'plugins', @engine_underscored_name, 'test', 'unit')      
    end
  end

protected
  def banner
    "Usage: #{$0} #{spec.name} MyEngine [general options]"
  end

  def create_sandbox
    sandbox = LicensingSandbox.new
    sandbox.author = @author
    sandbox
  end

end
