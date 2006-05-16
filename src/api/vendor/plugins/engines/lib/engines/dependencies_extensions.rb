module ::Dependencies
  
  # we're going to intercept the require_or_load method; lets
  # make an alias for the current method so we can use it as the basis
  # for loading from engines.
  alias :rails_pre_engines_require_or_load :require_or_load
  
  def require_or_load(file_name)
    if Engines.config(:edge)
      rails_edge_require_or_load(file_name)
    elsif Rails::VERSION::STRING =~ /^1.1/
      # otherwise, assume we're on trunk (1.1 at the moment)
      rails_1_1_require_or_load(file_name)
    elsif Rails::VERSION::STRING =~ /^1.0/
      # use the old dependency load method
      rails_1_0_require_or_load(file_name)
    end
  end
  
  def rails_edge_require_or_load(file_name)
    rails_1_1_require_or_load(file_name)
  end
  
  def rails_1_1_require_or_load(file_name)
    file_name = $1 if file_name =~ /^(.*)\.rb$/
    
    Engines.log.debug("Engines 1.1 require_or_load: #{file_name}")

    # try and load the engine code first
    # can't use model, as there's nothing in the name to indicate that the file is a 'model' file
    # rather than a library or anything else.
    ['controller', 'helper'].each do |type| 
      # if we recognise this type
      if file_name.include?('_' + type)
 
        # ... go through the active engines from first started to last, so that
        # code with a high precidence (started later) will override lower precidence
        # implementations
        Engines.each(:load_order) do |engine|
 
          engine_file_name = File.expand_path(File.join(engine.root, 'app', "#{type}s", file_name))
          engine_file_name = $1 if engine_file_name =~ /^(.*)\.rb$/
          Engines.log.debug("- checking engine '#{engine.name}' for '#{engine_file_name}'")
          if File.exist?("#{engine_file_name}.rb")
            Engines.log.debug("==> loading from engine '#{engine.name}'")
            rails_pre_engines_require_or_load(engine_file_name)
          end
        end
      end 
    end
    
    # finally, load any application-specific controller classes using the 'proper'
    # rails load mechanism
    rails_pre_engines_require_or_load(file_name)
  end
  
  
  def rails_1_0_require_or_load(file_name)
    file_name = $1 if file_name =~ /^(.*)\.rb$/

    Engines.log.debug "Engines 1.0.0 require_or_load '#{file_name}'"

    # if the file_name ends in "_controller" or "_controller.rb", strip all
    # path information out of it except for module context, and load it. Ditto
    # for helpers.
    if file_name =~ /_controller(.rb)?$/
      require_engine_files(file_name, 'controller')
    elsif file_name =~ /_helper(.rb)?$/ # any other files we can do this with?
      require_engine_files(file_name, 'helper')
    end
    
    # finally, load any application-specific controller classes using the 'proper'
    # rails load mechanism
    Engines.log.debug("--> loading from application: '#{file_name}'")
    rails_pre_engines_require_or_load(file_name)
    Engines.log.debug("--> Done loading.")
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
    processed_file_name = file_name.gsub(/[\w\W\/\.]*app\/#{type}s\//, '')    
    Engines.log.debug "--> rewrote to '#{processed_file_name}'"
    Engines.each(:load_order) do |engine|
      engine_file_name = File.join(engine.root, 'app', "#{type}s", processed_file_name)
      engine_file_name += '.rb' unless ! load? || engine_file_name[-3..-1] == '.rb'
      Engines.log.debug "--> checking '#{engine.name}' for #{engine_file_name}"
      if File.exist?(engine_file_name) || 
        (engine_file_name[-3..-1] != '.rb' && File.exist?(engine_file_name + '.rb'))
        Engines.log.debug "--> found, loading from engine '#{engine.name}'"
        rails_pre_engines_require_or_load(engine_file_name)
      end
    end     
  end
end


# We only need to deal with LoadingModules in Rails 1.0.0
if Rails::VERSION::STRING =~ /^1.0/ && !Engines.config(:edge)
  module ::Dependencies
    class RootLoadingModule < LoadingModule
      # hack to allow adding to the load paths within the Rails Dependencies mechanism.
      # this allows Engine classes to be unloaded and loaded along with standard
      # Rails application classes.
      def add_path(path)
        @load_paths << (path.kind_of?(ConstantLoadPath) ? path : ConstantLoadPath.new(path))
      end
    end
  end
end