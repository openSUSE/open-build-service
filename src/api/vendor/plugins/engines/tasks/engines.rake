desc "Display version information about active engines"
task :engine_info => :environment do
  if ENV["ENGINE"]
    # display information about that particular engine(s)?
    e = Engines.get(ENV["ENGINE"])
    header = "Details for engine '#{e.name}':"
    puts header
    puts "-" * header.length
    puts "Version: #{e.version}"
    puts "Details: #{e.info}"
  else
    puts "Engines plugin: #{Engines.version}"
    Engines.active.each do |e|
      puts "#{e.name}: #{e.version}"
    end
  end
end

desc "Migrate one or all engines, based on the migrations in that engines db/migrate dir"
task :engine_migrate => :environment do
  engines_to_migrate = Engines.active
  fail = false
  if ENV["ENGINE"]
    engines_to_migrate = [Engines.get(ENV["ENGINE"])].compact
    if engines_to_migrate.empty?
      puts "Couldn't find an engine called '#{ENV["ENGINE"]}'"
      fail = true
    end
  elsif ENV["VERSION"]
    # ignore the VERSION, since it makes no sense in this context; we wouldn't
    # want to revert ALL engines to the same version because of a misttype
    puts "Ignoring the given version (#{ENV["VERSION"]})."
    puts "To control individual engine versions, use the ENGINE=<engine> argument"
    fail = true
  end

  if !fail
    engines_to_migrate.each do |engine| 
      Engines::EngineMigrator.current_engine = engine
      migration_directory = File.join(engine.root, 'db', 'migrate')
      if File.exist?(migration_directory)
        puts "Migrating engine '#{engine.name}'"
        Engines::EngineMigrator.migrate(migration_directory, ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
        Rake::Task[:db_schema_dump].invoke if ActiveRecord::Base.schema_format == :ruby
      else
        puts "The db/migrate directory for engine '#{engine.name}' appears to be missing."
        puts "Should be: #{migration_directory}"
      end
    end
  end
end


# this is just a rip-off from the plugin stuff in railties/lib/tasks/documentation.rake, 
# because the default plugindoc stuff doesn't support subdirectories like app.
AllEngines = FileList['vendor/plugins/*_engine'].map {|engine| File.basename(engine)}
# Define doc tasks for each engine
AllEngines.each do |engine|
  task :"#{engine}_enginedoc" => :environment do
    engine_base   = "vendor/plugins/#{engine}"
    options       = []
    files         = Rake::FileList.new
    options << "-o doc/plugins/#{engine}"
    options << "--title '#{engine.titlecase} Documentation'"
    options << '--line-numbers --inline-source'
    options << '--all' # include protected methods
    options << '-T html'

    files.include("#{engine_base}/lib/**/*.rb")
    files.include("#{engine_base}/app/**/*.rb")
    if File.exists?("#{engine_base}/README")
      files.include("#{engine_base}/README")    
      options << "--main '#{engine_base}/README'"
    end
    files.include("#{engine_base}/CHANGELOG") if File.exists?("#{engine_base}/CHANGELOG")

    options << files.to_s

    sh %(rdoc #{options * ' '})
  end
end

desc "Generate documation for all installed engines"
task :enginedoc => AllEngines.map {|engine| :"#{engine}_enginedoc"}


desc "Load plugin/engine fixtures into the current environment's database."
task :load_plugin_fixtures => :environment do
  require 'active_record/fixtures'
  ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
  plugin = ENV['PLUGIN'] || '*'
  Dir.glob(File.join(RAILS_ROOT, 'vendor', 'plugins', plugin, 'test', 'fixtures', '*.yml')).each do |fixture_file|
    Fixtures.create_fixtures(File.dirname(fixture_file), File.basename(fixture_file, '.*'))
  end
end