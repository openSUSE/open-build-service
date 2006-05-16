#require 'active_record/connection_adapters/abstract/schema_statements'

module ::ActiveRecord::ConnectionAdapters::SchemaStatements
  alias :old_initialize_schema_information :initialize_schema_information
  def initialize_schema_information
    # create the normal schema stuff
    old_initialize_schema_information
    
    # create the engines schema stuff.    
    begin
      execute "CREATE TABLE #{engine_schema_info_table_name} (engine_name #{type_to_sql(:string)}, version #{type_to_sql(:integer)})"
    rescue ActiveRecord::StatementInvalid
      # Schema has been initialized
    end
  end

  def engine_schema_info_table_name
    ActiveRecord::Base.wrapped_table_name "engine_schema_info"
  end
end


require 'breakpoint'
module ::Engines
  class EngineMigrator < ActiveRecord::Migrator

    # We need to be able to set the 'current' engine being migrated.
    cattr_accessor :current_engine

    class << self

      def schema_info_table_name
        ActiveRecord::Base.wrapped_table_name "engine_schema_info"
      end

      def current_version
        result = ActiveRecord::Base.connection.select_one("SELECT version FROM #{schema_info_table_name} WHERE engine_name = '#{current_engine.name}'")
        if result
          result["version"].to_i
        else
          # There probably isn't an entry for this engine in the migration info table.
          # We need to create that entry, and set the version to 0
          ActiveRecord::Base.connection.execute("INSERT INTO #{schema_info_table_name} (version, engine_name) VALUES (0,'#{current_engine.name}')")      
          0
        end
      end    
    end

    def set_schema_version(version)
      ActiveRecord::Base.connection.update("UPDATE #{self.class.schema_info_table_name} SET version = #{down? ? version.to_i - 1 : version.to_i} WHERE engine_name = '#{self.current_engine.name}'")
    end
  end
end
