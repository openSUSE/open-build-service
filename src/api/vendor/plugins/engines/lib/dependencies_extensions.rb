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

module ::Dependencies
  def require_or_load(file_name)
    Engines.log.debug "Engines' require_or_load for '#{file_name}'"

    # if the file_name ends in "_controller" or "_controller.rb", strip all
    # path information out of it except for module context, and load it. Ditto
    # for helpers.
    if file_name =~ /_controller(.rb)?$/
      require_engine_files(file_name, 'controller')
    elsif file_name =~ /_helper(.rb)?$/ # any other files we can do this with?
      require_engine_files(file_name, 'helper')
    end
    
    # finally, load any application-specific controller classes.
    file_name = "#{file_name}.rb" unless ! load? || file_name [-3..-1] == '.rb'
    Engines.log.debug "finally loading from application: '#{file_name}'"
    load? ? load(file_name) : require(file_name)
  end
  
  # Load the given file (which should be a path to be matched from the root of each
  # engine) from all active engines which have that file.
  # NOTE! this method automagically strips file_name up to and including the first
  # instance of '/app/controller'. This should correspond to the app/controller folder
  # under RAILS_ROOT. However, if you have your Rails application residing under a
  # path which includes /app/controller anyway, such as:
  #
  #   /home/username/app/controller/my_web_application # == RAILS_ROOT
  #
  # then you might have trouble. Sorry, just please don't have your web application
  # running under a path like that.
  def require_engine_files(file_name, type='')
    Engines.log.debug "requiring #{type} file '#{file_name}'"
    processed_file_name = file_name.gsub(/[\w\/\.]*app\/#{type}s\//, '')    
    Engines.log.debug "--> rewrote to '#{processed_file_name}'"
    Engines.active.reverse.each do |engine|
      engine_file_name = File.join(engine.root, 'app', "#{type}s", processed_file_name)
      engine_file_name += '.rb' unless ! load? || engine_file_name[-3..-1] == '.rb'
      Engines.log.debug "--> checking '#{engine.name}' for #{engine_file_name}"
      if File.exist?(engine_file_name) || 
        (engine_file_name[-3..-1] != '.rb' && File.exist?(engine_file_name + '.rb'))
        Engines.log.debug "--> found, loading from engine '#{engine.name}'"
        load? ? load(engine_file_name) : require(engine_file_name)
      end
    end     
  end

  class RootLoadingModule < LoadingModule
    # hack to allow adding to the load paths within the Rails Dependencies mechanism.
    # this allows Engine classes to be unloaded and loaded along with standard
    # Rails application classes.
    def add_path(path)
      @load_paths << (path.kind_of?(ConstantLoadPath) ? path : ConstantLoadPath.new(path))
    end
  end
end