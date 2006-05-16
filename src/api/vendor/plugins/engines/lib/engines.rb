require 'logger'

# We need to know the version of Rails that we are running before we
# can override any of the dependency stuff, since Rails' own behaviour
# has changed over the various releases. We need to explicily make sure
# that the Rails::VERSION constant is loaded, because such things could
# not automatically be achieved prior to 1.1, and the location of the
# file moved in 1.1.1!
def load_rails_version
  # At this point, we can't even rely on RAILS_ROOT existing, so we have to figure
  # the path to RAILS_ROOT/vendor/rails manually
  rails_base = File.expand_path(
    File.join(File.dirname(__FILE__), # RAILS_ROOT/vendor/plugins/engines/lib
    '..', # RAILS_ROOT/vendor/plugins/engines
    '..', # RAILS_ROOT/vendor/plugins
    '..', # RAILS_ROOT/vendor
    'rails', 'railties', 'lib')) # RAILS_ROOT/vendor/rails/railties/lib
  begin
    load File.join(rails_base, 'rails', 'version.rb')
    #puts 'loaded 1.1.1+ from vendor: ' + File.join(rails_base, 'rails', 'version.rb')
  rescue MissingSourceFile # this means they DON'T have Rails 1.1.1 or later installed in vendor
    begin
      load File.join(rails_base, 'rails_version.rb')
      #puts 'loaded 1.1.0- from vendor: ' + File.join(rails_base, 'rails_version.rb')
    rescue MissingSourceFile # this means they DON'T have Rails 1.1.0 or previous installed in vendor
      begin
        # try and load version information for Rails 1.1.1 or later from the $LOAD_PATH
        require 'rails/version'
        #puts 'required 1.1.1+ from load path'
      rescue LoadError
        # try and load version information for Rails 1.1.0 or previous from the $LOAD_PATH
        require 'rails_version'
        #puts 'required 1.1.0- from load path'
      end
    end
  end
end

# Actually perform the load
load_rails_version
#puts "Detected Rails version: #{Rails::VERSION::STRING}"

require 'engines/ruby_extensions'
# ... further files are required at the bottom of this file

# Holds the Rails Engine loading logic and default constants
module Engines

  class << self
    # Return the version string for this plugin
    def version
      "#{Version::Major}.#{Version::Minor}.#{Version::Release}"
    end
  end

  # The DummyLogger is a class which might pass through to a real Logger
  # if one is assigned. However, it can gracefully swallow any logging calls
  # if there is now Logger assigned.
  class LoggerWrapper
    def initialize(logger=nil)
      set_logger(logger)
    end
    # Assign the 'real' Logger instance that this dummy instance wraps around.
    def set_logger(logger)
      @logger = logger
    end
    # log using the appropriate method if we have a logger
    # if we dont' have a logger, ignore completely.
    def method_missing(name, *args)
      if @logger && @logger.respond_to?(name)
        @logger.send(name, *args)
      end
    end
  end

  LOGGER = Engines::LoggerWrapper.new

  class << self
    # Create a new Logger instance for Engines, with the given outputter and level    
    def create_logger(outputter=STDOUT, level=Logger::INFO)
      LOGGER.set_logger(Logger.new(outputter, level))
    end
    # Sets the Logger instance that Engines will use to send logging information to
    def set_logger(logger)
      Engines::LOGGER.set_logger(logger) # TODO: no need for Engines:: part
    end
    # Retrieves the current Logger instance
    def log
      Engines::LOGGER # TODO: no need for Engines:: part
    end
    alias :logger :log
  end
  
  # An array of active engines. This should be accessed via the Engines.active method.
  ActiveEngines = []
  
  # The root directory for engines
  config :root, File.join(RAILS_ROOT, "vendor", "plugins")
  
  # The name of the public folder under which engine files are copied
  config :public_dir, "engine_files"
  
  class << self
  
    # Initializes a Rails Engine by loading the engine's init.rb file and
    # ensuring that any engine controllers are added to the load path.
    # This will also copy any files in a directory named 'public'
    # into the public webserver directory. Example usage:
    #
    #   Engines.start :login
    #   Engines.start :login_engine  # equivalent
    #
    # A list of engine names can be specified:
    #
    #   Engines.start :login, :user, :wiki
    #
    # The engines will be loaded in the order given.
    # If no engine names are given, all engines will be started.
    #
    # Options can include:
    # * :copy_files => true | false
    #
    # Note that if a list of engines is given, the options will apply to ALL engines.
    def start(*args)
      
      options = (args.last.is_a? Hash) ? args.pop : {}
      
      if args.empty?
        start_all
      else
        args.each do |engine_name|
          start_engine(engine_name, options)
        end
      end
    end

    # Starts all available engines. Plugins are considered engines if they
    # include an init_engine.rb file, or they are named <something>_engine.
    def start_all
      plugins = Dir[File.join(config(:root), "*")]
      Engines.log.debug "considering plugins: #{plugins.inspect}"
      plugins.each { |plugin|
        engine_name = File.basename(plugin)
        if File.exist?(File.join(plugin, "init_engine.rb")) || # if the directory contains an init_engine.rb file
          (engine_name =~ /_engine$/) || # or it engines in '_engines'
          (engine_name =~ /_bundle$/)    # or even ends in '_bundle'
          
          start(engine_name) # start the engine...
        
        end
      }
    end

    def start_engine(engine_name, options={})
      
      # Create a new Engine and put this engine at the front of the ActiveEngines list
      current_engine = Engine.new(engine_name)
      Engines.active.unshift current_engine
      Engines.log.info "Starting engine '#{current_engine.name}' from '#{File.expand_path(current_engine.root)}'"

      # add the code directories of this engine to the load path
      add_engine_to_load_path(current_engine)

      # add the controller & component path to the Dependency system
      engine_controllers = File.join(current_engine.root, 'app', 'controllers')
      engine_components = File.join(current_engine.root, 'components')


      # This mechanism is no longer required in Rails trunk
      if Rails::VERSION::STRING =~ /^1.0/ && !Engines.config(:edge)
        Controllers.add_path(engine_controllers) if File.exist?(engine_controllers)
        Controllers.add_path(engine_components) if File.exist?(engine_components)
      end
        
      # copy the files unless indicated otherwise
      if options[:copy_files] != false
        current_engine.mirror_engine_files
      end

      # load the engine's init.rb file
      startup_file = File.join(current_engine.root, "init_engine.rb")
      if File.exist?(startup_file)
        eval(IO.read(startup_file), binding, startup_file)
        # possibly use require_dependency? Hmm.
      else
        Engines.log.debug "No init_engines.rb file found for engine '#{current_engine.name}'..."
      end
    end

    # Adds all directories in the /app and /lib directories within the engine
    # to the load path
    def add_engine_to_load_path(engine)
      
      # remove the lib directory added by load_plugin, and place it in the corrent
      # location *after* the application/lib. This can be removed when 
      # http://dev.rubyonrails.org/ticket/2910 is fixed.
      app_lib_index = $LOAD_PATH.index(File.join(RAILS_ROOT, "lib"))
      engine_lib = File.join(engine.root, "lib")
      if app_lib_index
        $LOAD_PATH.delete(engine_lib)
        $LOAD_PATH.insert(app_lib_index+1, engine_lib)
      end
      
      # Add ALL paths under the engine root to the load path
      app_dirs = %w(controllers helpers models).collect { |d|
        File.join(engine.root, 'app', d)
      }
      other_dirs = %w(components lib).collect { |d| 
        File.join(engine.root, d)
      }
      load_paths  = (app_dirs + other_dirs).select { |d| File.directory?(d) }

      # Remove other engines from the $LOAD_PATH by matching against the engine.root values
      # in ActiveEngines. Store the removed engines in the order they came off.
      
      old_plugin_paths = []
      # assumes that all engines are at the bottom of the $LOAD_PATH
      while (File.expand_path($LOAD_PATH.last).index(File.expand_path(Engines.config(:root))) == 0) do
        old_plugin_paths.unshift($LOAD_PATH.pop)
      end


      # add these LAST on the load path.
      load_paths.reverse.each { |dir| 
        if File.directory?(dir)
          Engines.log.debug "adding #{File.expand_path(dir)} to the load path"
          #$LOAD_PATH.push(File.expand_path(dir))
          $LOAD_PATH.push dir
        end
      }
      
      # Add the other engines back onto the bottom of the $LOAD_PATH. Put them back on in
      # the same order.
      $LOAD_PATH.push(*old_plugin_paths)
      $LOAD_PATH.uniq!
    end

    # Returns the directory in which all engine public assets are mirrored.
    def public_engine_dir
      File.expand_path(File.join(RAILS_ROOT, "public", Engines.config(:public_dir)))
    end
  
    # create the /public/engine_files directory if it doesn't exist
    def create_base_public_directory
      if !File.exists?(public_engine_dir)
        # create the public/engines directory, with a warning message in it.
        Engines.log.debug "Creating public engine files directory '#{public_engine_dir}'"
        FileUtils.mkdir(public_engine_dir)
        File.open(File.join(public_engine_dir, "README"), "w") do |f|
          f.puts <<EOS
Files in this directory are automatically generated from your Rails Engines.
They are copied from the 'public' directories of each engine into this directory
each time Rails starts (server, console... any time 'start_engine' is called).
Any edits you make will NOT persist across the next server restart; instead you
should edit the files within the <engine_name>/public/ directory itself.
EOS
        end
      end
    end
    
    # Returns the Engine object for the specified engine, e.g.:
    #    Engines.get(:login)  
    def get(name)
      active.find { |e| e.name == name.to_s || e.name == "#{name}_engine" }
    end
    alias_method :[], :get
    
    # Returns the Engine object for the current engine, i.e. the engine
    # in which the currently executing code lies.
    def current
      current_file = caller[0]
      active.find do |engine|
        File.expand_path(current_file).index(File.expand_path(engine.root)) == 0
      end
    end
    
    # Returns an array of active engines
    def active
      ActiveEngines
    end
    
    # Pass a block to perform an operation on each engine. You may pass an argument
    # to determine the order:
    # 
    # * :load_order - in the order they were loaded (i.e. lower precidence engines first).
    # * :precidence_order - highest precidence order (i.e. last loaded) first
    def each(ordering=:precidence_order, &block)
      engines = (ordering == :load_order) ? active.reverse : active
      engines.each { |e| yield e }
    end
  end 
end

# A simple class for holding information about loaded engines
class Engine
  
  # Returns the base path of this engine
  attr_accessor :root
  
  # Returns the name of this engine
  attr_reader :name
  
  # An attribute for holding the current version of this engine. There are three
  # ways of providing an engine version. The simplest is using a string:
  #
  #   Engines.current.version = "1.0.7"
  #
  # Alternatively you can set it to a module which contains Major, Minor and Release
  # constants:
  #
  #   module LoginEngine::Version
  #     Major = 1; Minor = 0; Release = 6;
  #   end
  #   Engines.current.version = LoginEngine::Version
  #
  # Finally, you can set it to your own Proc, if you need something really fancy:
  #
  #   Engines.current.version = Proc.new { File.open('VERSION', 'r').readlines[0] }
  # 
  attr_writer :version
  
  # Engine developers can store any information they like in here.
  attr_writer :info
  
  # Creates a new object holding information about an Engine.
  def initialize(name)

    @root = ''
    suffixes = ['', '_engine', '_bundle']
    while !File.exist?(@root) && !suffixes.empty?
      suffix = suffixes.shift
      @root = File.join(Engines.config(:root), name.to_s + suffix)
    end

    if !File.exist?(@root)
      raise "Cannot find the engine '#{name}' in either /vendor/plugins/#{name}, " +
        "/vendor/plugins/#{name}_engine or /vendor/plugins/#{name}_bundle."
    end      
    
    @name = File.basename(@root)
  end
    
  # Returns the version string of this engine
  def version
    case @version
    when Module
      "#{@version::Major}.#{@version::Minor}.#{@version::Release}"
    when Proc         # not sure about this
      @version.call
    when NilClass
      'unknown'
    else
      @version
    end
  end
  
  # Returns a string describing this engine
  def info
    @info || '(none)'
  end
    
  # Returns a string representation of this engine
  def to_s
    "Engine<'#{@name}' [#{version}]:#{root.gsub(RAILS_ROOT, '')}>"
  end
  
  # return the path to this Engine's public files (with a leading '/' for use in URIs)
  def public_dir
    File.join("/", Engines.config(:public_dir), name)
  end
  
  # Replicates the subdirectories under the engine's /public directory into
  # the corresponding public directory.
  def mirror_engine_files
    
    begin
      Engines.create_base_public_directory
  
      source = File.join(root, "public")
      Engines.log.debug "Attempting to copy public engine files from '#{source}'"
  
      # if there is no public directory, just return after this file
      return if !File.exist?(source)

      source_files = Dir[source + "/**/*"]
      source_dirs = source_files.select { |d| File.directory?(d) }
      source_files -= source_dirs  
    
      Engines.log.debug "source dirs: #{source_dirs.inspect}"

      # Create the engine_files/<something>_engine dir if it doesn't exist
      new_engine_dir = File.join(RAILS_ROOT, "public", public_dir)
      if !File.exists?(new_engine_dir)
        # Create <something>_engine dir with a message
        Engines.log.debug "Creating #{public_dir} public dir"
        FileUtils.mkdir_p(new_engine_dir)
      end

      # create all the directories, transforming the old path into the new path
      source_dirs.uniq.each { |dir|
        begin        
          # strip out the base path and add the result to the public path, i.e. replace 
          #   ../script/../vendor/plugins/engine_name/public/javascript
          # with
          #   engine_name/javascript
          #
          relative_dir = dir.gsub(File.join(root, "public"), name)
          target_dir = File.join(Engines.public_engine_dir, relative_dir)
          unless File.exist?(target_dir)
            Engines.log.debug "creating directory '#{target_dir}'"
            FileUtils.mkdir_p(target_dir)
          end
        rescue Exception => e
          raise "Could not create directory #{target_dir}: \n" + e
        end
      }

      # copy all the files, transforming the old path into the new path
      source_files.uniq.each { |file|
        begin
          # change the path from the ENGINE ROOT to the public directory root for this engine
          target = file.gsub(File.join(root, "public"), 
                             File.join(Engines.public_engine_dir, name))
          unless File.exist?(target) && FileUtils.identical?(file, target)
            Engines.log.debug "copying file '#{file}' to '#{target}'"
            FileUtils.cp(file, target)
          end 
        rescue Exception => e
          raise "Could not copy #{file} to #{target}: \n" + e 
        end
      }
    rescue Exception => e
      Engines.log.warn "WARNING: Couldn't create the engine public file structure for engine '#{name}'; Error follows:"
      Engines.log.warn e
    end
  end  
end


# These files must be required after the Engines module has been defined.
require 'engines/dependencies_extensions'
require 'engines/action_view_extensions'
require 'engines/action_mailer_extensions'
require 'engines/migration_extensions'
require 'engines/active_record_extensions'

# only load the testing extensions if we are in the test environment
require 'engines/testing_extensions' if %w(test).include?(RAILS_ENV)
