#require 'active_record/connection_adapters/abstract/schema_statements'

module ::ActiveRecord::ConnectionAdapters::SchemaStatements
  alias :old_initialize_schema_information :initialize_schema_information
  def initialize_schema_information
    # create the normal schema stuff
    old_initialize_schema_information
    
    # create the engines schema stuff.    
    begin
      execute "CREATE TABLE engine_schema_info (engine_name #{type_to_sql(:string)}, version #{type_to_sql(:integer)})"
    rescue ActiveRecord::StatementInvalid
      # Schema has been initialized
    end
  end
end


require 'breakpoint'
module ::Engines
  class EngineMigrator < ActiveRecord::Migrator

    # We need to be able to set the 'current' engine being migrated.
    cattr_accessor :current_engine
    cattr_accessor :schema_info_table_name
  
    class << self

      def current_version
        result = ActiveRecord::Base.connection.select_one("SELECT version FROM engine_schema_info WHERE engine_name = '#{current_engine.name}'")
        if result
          result["version"].to_i
        else
          # set the version to 0
          ActiveRecord::Base.connection.execute("INSERT INTO engine_schema_info (version, engine_name) VALUES (0,'#{current_engine.name}')")      
          0
        end
      end    
    end

    def set_schema_version(version)
      ActiveRecord::Base.connection.update("UPDATE engine_schema_info SET version = #{down? ? version.to_i - 1 : version.to_i} WHERE engine_name = '#{self.current_engine.name}'")
    end
  end
end
