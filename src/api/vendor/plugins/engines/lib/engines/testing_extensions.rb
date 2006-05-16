# The Engines testing extensions enable developers to load fixtures into specific
# tables irrespective of the name of the fixtures file. This work is heavily based on
# patches made by Duane Johnson (canadaduane), viewable at
# http://dev.rubyonrails.org/ticket/1911
#
# Engine developers should supply fixture files in the <engine>/test/fixtures directory
# as normal. Within their tests, they should load the fixtures using the 'fixture' command
# (rather than the normal 'fixtures' command). For example:
#
#   class UserTest < Test::Unit::TestCase
#     fixture :users, :table_name => LoginEngine.config(:user_table), :class_name => "User"
#    
#     ...
#
# This will ensure that the fixtures/users.yml file will get loaded into the correct
# table, and will use the correct model object class.



# A FixtureGroup is a set of fixtures identified by a name.  Normally, this is the name of the
# corresponding fixture filename.  For example, when you declare the use of fixtures in a
# TestUnit class, like so:
#   fixtures :users
# you are creating a FixtureGroup whose name is 'users', and whose defaults are set such that the
# +class_name+, +file_name+ and +table_name+ are guessed from the FixtureGroup's name.
class FixtureGroup
  attr_accessor :table_name, :class_name, :connection
  attr_reader :group_name, :file_name

  def initialize(file_name, optional_names = {})
    self.file_name = file_name
    self.group_name = optional_names[:group_name] || file_name
    if optional_names[:table_name]
      self.table_name = optional_names[:table_name]
      self.class_name = optional_names[:class_name] || Inflector.classify(@table_name.to_s.gsub('.','_'))
    elsif optional_names[:class_name]
      self.class_name = optional_names[:class_name]
      if Object.const_defined?(@class_name)
        model_class = Object.const_get(@class_name)
        self.table_name = ActiveRecord::Base.table_name_prefix + model_class.table_name + ActiveRecord::Base.table_name_suffix
      end
    end

    # In case either :table_name or :class_name was not set:
    self.table_name ||= ActiveRecord::Base.table_name_prefix + @group_name.to_s + ActiveRecord::Base.table_name_suffix
    self.class_name ||= Inflector.classify(@table_name.to_s.gsub('.','_'))
  end

  def file_name=(name)
    @file_name = name.to_s
  end
  
  def group_name=(name)
    @group_name = name.to_sym
  end

  def class_file_name
    Inflector.underscore(@class_name)
  end
  
  # Instantiate an array of FixtureGroup objects from an array of strings (table_names)
  def self.array_from_names(names)
    names.collect { |n| FixtureGroup.new(n) }
  end
  
  def hash
    @group_name.hash
  end
  
  def eql?(other)
    @group_name.eql? other.group_name
  end
end

class Fixtures < YAML::Omap

  def self.instantiate_fixtures(object, fixture_group_name, fixtures, load_instances=true)
    old_logger_level = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = Logger::ERROR

    # table_name.to_s.gsub('.','_') replaced by 'fixture_group_name'
    object.instance_variable_set "@#{fixture_group_name}", fixtures
    if load_instances
      ActiveRecord::Base.silence do
        fixtures.each do |name, fixture|
          if model = fixture.find
            object.instance_variable_set "@#{name}", model
          end
        end
      end
    end

    ActiveRecord::Base.logger.level = old_logger_level
  end

  # this doesn't really need to be overridden...
  def self.instantiate_all_loaded_fixtures(object, load_instances=true)
    all_loaded_fixtures.each do |fixture_group_name, fixtures|
      Fixtures.instantiate_fixtures(object, fixture_group_name, fixtures, load_instances)
    end
  end

  def self.create_fixtures(fixtures_directory, *fixture_groups)
    connection = block_given? ? yield : ActiveRecord::Base.connection
    fixture_groups.flatten!
    
    # Backwards compatibility: Allow an array of table names to be passed in, but just use them
    # to create an array of FixtureGroup objects
    if not fixture_groups.empty? and fixture_groups.first.is_a?(String)
      fixture_groups = FixtureGroup.array_from_names(fixture_groups)
    end

    ActiveRecord::Base.silence do
      fixtures_map = {}
      fixtures = fixture_groups.map do |group|
        fixtures_map[group.group_name] = Fixtures.new(connection, fixtures_directory, group)
      end 
      # Make sure all refs to all_loaded_fixtures use group_name as hash index, not table_name
      all_loaded_fixtures.merge! fixtures_map 

      connection.transaction do
        fixtures.reverse.each { |fixture| fixture.delete_existing_fixtures }
        fixtures.each { |fixture| fixture.insert_fixtures }
        
        # Cap primary key sequences to max(pk).
        if connection.respond_to?(:reset_pk_sequence!)
          fixture_groups.each do |fg|
            connection.reset_pk_sequence!(fg.table_name)
          end
        end
      end

      return fixtures.size > 1 ? fixtures : fixtures.first
    end
  end

 
  attr_accessor :connection, :fixtures_directory, :file_filter
  attr_accessor :fixture_group
 
  def initialize(connection, fixtures_directory, fixture_group, file_filter = DEFAULT_FILTER_RE)
    @connection, @fixtures_directory = connection, fixtures_directory
    @fixture_group = fixture_group
    @file_filter = file_filter
    read_fixture_files
  end
 
  def delete_existing_fixtures
    @connection.delete "DELETE FROM #{@fixture_group.table_name}", 'Fixture Delete'
  end
 
  def insert_fixtures
    values.each do |fixture|
      @connection.execute "INSERT INTO #{@fixture_group.table_name} (#{fixture.key_list}) VALUES (#{fixture.value_list})", 'Fixture Insert'
    end
  end
 
  private
    def read_fixture_files
      if File.file?(yaml_file_path)
        read_yaml_fixture_files
      elsif File.file?(csv_file_path)
        read_csv_fixture_files
      elsif File.file?(deprecated_yaml_file_path)
        raise Fixture::FormatError, ".yml extension required: rename #{deprecated_yaml_file_path} to #{yaml_file_path}"
      elsif File.directory?(single_file_fixtures_path)
        read_standard_fixture_files
      else
        raise Fixture::FixtureError, "Couldn't find a yaml, csv or standard file to load at #{@fixtures_directory} (#{@fixture_group.file_name})."
      end
    end

    def read_yaml_fixture_files
      # YAML fixtures
      begin
        if yaml = YAML::load(erb_render(IO.read(yaml_file_path)))
          yaml = yaml.value if yaml.respond_to?(:type_id) and yaml.respond_to?(:value)
          yaml.each do |name, data|
            self[name] = Fixture.new(data, fixture_group.class_name)
          end
        end
      rescue Exception=>boom
        raise Fixture::FormatError, "a YAML error occured parsing #{yaml_file_path}. Please note that YAML must be consistently indented using spaces. Tabs are not allowed. Please have a look at http://www.yaml.org/faq.html\nThe exact error was:\n  #{boom.class}: #{boom}"
      end      
    end

    def read_csv_fixture_files
      # CSV fixtures
      reader = CSV::Reader.create(erb_render(IO.read(csv_file_path)))
      header = reader.shift
      i = 0
      reader.each do |row|
        data = {}
        row.each_with_index { |cell, j| data[header[j].to_s.strip] = cell.to_s.strip }
        self["#{@fixture_group.class_file_name}_#{i+=1}"]= Fixture.new(data, @fixture_group.class_name)
      end
    end

    def read_standard_fixture_files
      # Standard fixtures
      path = File.join(@fixtures_directory, @fixture_group.file_name)
      Dir.entries(path).each do |file|
        path = File.join(@fixtures_directory, @fixture_group.file_name, file)
        if File.file?(path) and file !~ @file_filter
          self[file] = Fixture.new(path, @fixture_group.class_name)
        end
      end
    end
 
    def yaml_file_path
      fixture_path_with_extension ".yml"
    end
 
    def deprecated_yaml_file_path
      fixture_path_with_extension ".yaml"
    end
 
    def csv_file_path
      fixture_path_with_extension ".csv"
    end
    
    def single_file_fixtures_path
      fixture_path_with_extension ""
    end
 
    def fixture_path_with_extension(ext)
      File.join(@fixtures_directory, @fixture_group.file_name + ext)
    end 

    def erb_render(fixture_content)
      ERB.new(fixture_content).result
    end

end

module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:
      cattr_accessor :fixtures_directory
      class_inheritable_accessor :fixture_groups
      class_inheritable_accessor :fixture_table_names
      class_inheritable_accessor :use_transactional_fixtures
      class_inheritable_accessor :use_instantiated_fixtures   # true, false, or :no_instances
      class_inheritable_accessor :pre_loaded_fixtures

      self.fixture_groups = []
      self.use_transactional_fixtures = false
      self.use_instantiated_fixtures = true
      self.pre_loaded_fixtures = false

      @@already_loaded_fixtures = {}

      # Backwards compatibility
      def self.fixture_path=(path); self.fixtures_directory = path; end
      def self.fixture_path; self.fixtures_directory; end
      def fixture_group_names; fixture_groups.collect { |g| g.group_name }; end
      def fixture_table_names; fixture_group_names; end

      def self.fixture(file_name, options = {})
        self.fixture_groups |= [FixtureGroup.new(file_name, options)]
        require_fixture_classes
        setup_fixture_accessors
      end

      def self.fixtures(*file_names)
        self.fixture_groups |= FixtureGroup.array_from_names(file_names.flatten)
        require_fixture_classes
        setup_fixture_accessors
      end

      def self.require_fixture_classes(fixture_groups_override = nil)
        (fixture_groups_override || fixture_groups).each do |group| 
          begin
            require group.class_file_name
          rescue LoadError
            # Let's hope the developer has included it himself
          end
        end
      end

      def self.setup_fixture_accessors(fixture_groups_override=nil)
        (fixture_groups_override || fixture_groups).each do |group|
          define_method(group.group_name) do |fixture, *optionals|
            force_reload = optionals.shift
            @fixture_cache[group.group_name] ||= Hash.new
            @fixture_cache[group.group_name][fixture] = nil if force_reload
            @fixture_cache[group.group_name][fixture] ||= @loaded_fixtures[group.group_name][fixture.to_s].find
          end
        end
      end

      private
        def load_fixtures
          @loaded_fixtures = {}
          fixtures = Fixtures.create_fixtures(fixtures_directory, fixture_groups)
          unless fixtures.nil?
            if fixtures.instance_of?(Fixtures)
              @loaded_fixtures[fixtures.fixture_group.group_name] = fixtures
            else
              fixtures.each { |f| @loaded_fixtures[f.fixture_group.group_name] = f }
            end
          end
        end

        def instantiate_fixtures
          if pre_loaded_fixtures
            raise RuntimeError, 'Load fixtures before instantiating them.' if Fixtures.all_loaded_fixtures.empty?
            unless @@required_fixture_classes
              groups = Fixtures.all_loaded_fixtures.values.collect { |f| f.group_name }
              self.class.require_fixture_classes groups
              @@required_fixture_classes = true
            end
            Fixtures.instantiate_all_loaded_fixtures(self, load_instances?)
          else
            raise RuntimeError, 'Load fixtures before instantiating them.' if @loaded_fixtures.nil?
            @loaded_fixtures.each do |fixture_group_name, fixtures|
              Fixtures.instantiate_fixtures(self, fixture_group_name, fixtures, load_instances?)
            end
          end
        end
    end
  end
end
