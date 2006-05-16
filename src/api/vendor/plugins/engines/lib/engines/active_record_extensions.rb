module ::ActiveRecord
  class Base
    class << self
      
      # NOTE: Currently the Migrations system will ALWAYS wrap given table names
      # in the prefix/suffix, so any table name set via config(:table_name), for instnace
      # will always get wrapped in the process of migration. For this reason, whatever
      # value you give to the config will be wrapped when set_table_name is used in the
      # model.
      
      def wrapped_table_name(name)
        table_name_prefix + name + table_name_suffix
      end
    end
  end
end

# Set ActiveRecord to ignore the engine_schema_info table by default
unless Rails::VERSION::STRING =~ /^1\.0\./
  ::ActiveRecord::SchemaDumper.ignore_tables << 'engine_schema_info'
end