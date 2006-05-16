module Engines
  module RakeTasks
    def self.all_engines
      # An engine is informally defined as any subdirectory in vendor/plugins
      # which ends in '_engine', '_bundle', or contains an 'init_engine.rb' file.
      engine_base_dirs = ['vendor/plugins']
      # The engine root may be different; if possible try to include
      # those directories too
      if Engines.const_defined?(:CONFIG)
        engine_base_dirs << Engines::CONFIG[:root]
      end
      engine_base_dirs.map! {|d| [d + '/*_engine/*', 
                                  d + '/*_bundle/*',
                                  d + '/*/init_engine.rb']}.flatten!
      engine_dirs = FileList.new(*engine_base_dirs)
      engine_dirs.map do |engine| 
        File.basename(File.dirname(engine))
      end.uniq       
    end
  end
end


namespace :engines do
  desc "Display version information about active engines"
  task :info => :environment do
    if ENV["ENGINE"]
      e = Engines.get(ENV["ENGINE"])
      header = "Details for engine '#{e.name}':"
      puts header
      puts "-" * header.length
      puts "Version: #{e.version}"
      puts "Details: #{e.info}"
    else
      puts "Engines plugin: #{Engines.version}"
      Engines.each do |e|
        puts "#{e.name}: #{e.version}"
      end
    end
  end
end

namespace :db do  
  namespace :fixtures do
    namespace :engines do
      
      desc "Load plugin/engine fixtures into the current environment's database."
      task :load => :environment do
        require 'active_record/fixtures'
        ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
        plugin = ENV['ENGINE'] || '*'
        Dir.glob(File.join(RAILS_ROOT, 'vendor', 'plugins', plugin, 'test', 'fixtures', '*.yml')).each do |fixture_file|
          Fixtures.create_fixtures(File.dirname(fixture_file), File.basename(fixture_file, '.*'))
        end
      end
      
    end
  end


  namespace :migrate do
    
    desc "Migrate all engines. Target specific version with VERSION=x, specific engine with ENGINE=x"
    task :engines => :environment do
      engines_to_migrate = ENV["ENGINE"] ? [Engines.get(ENV["ENGINE"])].compact : Engines.active
      if engines_to_migrate.empty?
        puts "Couldn't find an engine called '#{ENV["ENGINE"]}'"
      else
        if ENV["VERSION"] && !ENV["ENGINE"]
          # ignore the VERSION, since it makes no sense in this context; we wouldn't
          # want to revert ALL engines to the same version because of a misttype
          puts "Ignoring the given version (#{ENV["VERSION"]})."
          puts "To control individual engine versions, use the ENGINE=<engine> argument"
        else
          engines_to_migrate.each do |engine| 
            Engines::EngineMigrator.current_engine = engine
            migration_directory = File.join(engine.root, 'db', 'migrate')
            if File.exist?(migration_directory)
              puts "Migrating engine '#{engine.name}'"
              Engines::EngineMigrator.migrate(migration_directory, ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
            else
              puts "The db/migrate directory for engine '#{engine.name}' appears to be missing."
              puts "Should be: #{migration_directory}"
            end
          end
          if ActiveRecord::Base.schema_format == :ruby && !engines_to_migrate.empty?
            Rake::Task[:db_schema_dump].invoke
          end
        end
      end
    end

    namespace :engines do
      Engines::RakeTasks.all_engines.each do |engine_name|
        desc "Migrate the '#{engine_name}' engine. Target specific version with VERSION=x"
        task engine_name => :environment do
          ENV['ENGINE'] = engine_name; Rake::Task['db:migrate:engines'].invoke
        end
      end
    end
    
  end
end


# this is just a rip-off from the plugin stuff in railties/lib/tasks/documentation.rake, 
# because the default plugindoc stuff doesn't support subdirectories like <engine>/app or
# <engine>/component.
namespace :doc do

  desc "Generate documation for all installed engines"
  task :engines => Engines::RakeTasks.all_engines.map {|engine| "doc:engines:#{engine}"}

  namespace :engines do
    # Define doc tasks for each engine
    Engines::RakeTasks.all_engines.each do |engine_name|
      desc "Generation documentation for the '#{engine_name}' engine"
      task engine_name => :environment do
        engine_base   = "vendor/plugins/#{engine_name}"
        options       = []
        files         = Rake::FileList.new
        options << "-o doc/plugins/#{engine_name}"
        options << "--title '#{engine_name.titlecase} Documentation'"
        options << '--line-numbers --inline-source'
        options << '--all' # include protected methods
        options << '-T html'

        files.include("#{engine_base}/lib/**/*.rb")
        files.include("#{engine_base}/app/**/*.rb") # include the app directory
        files.include("#{engine_base}/components/**/*.rb") # include the components directory
        if File.exists?("#{engine_base}/README")
          files.include("#{engine_base}/README")    
          options << "--main '#{engine_base}/README'"
        end
        files.include("#{engine_base}/CHANGELOG") if File.exists?("#{engine_base}/CHANGELOG")

        options << files.to_s

        sh %(rdoc #{options * ' '})
      end
    end
  end
end

namespace :test do
  desc "Run the engine tests in vendor/plugins/**/test (or specify with ENGINE=name)"
  # NOTE: we're using the Rails 1.0 non-namespaced task here, just to maintain
  # compatibility with Rails 1.0
  # TODO: make this work with Engines.config(:root)
  Rake::TestTask.new(:engines => :prepare_test_database) do |t|
    t.libs << "test"

    if ENV['ENGINE']
      t.pattern = "vendor/plugins/#{ENV['ENGINE']}/test/**/*_test.rb"
    else
      t.pattern = 'vendor/plugins/**/test/**/*_test.rb'
    end

    t.verbose = true
  end  
end