class AddReleaseTargetConstraints < ActiveRecord::Migration
  def self.up
    sql =<<-END_SQL
alter table release_targets add FOREIGN KEY (repository_id) references repositories (id);
alter table release_targets add FOREIGN KEY (target_repository_id) references repositories (id);
END_SQL

    sql.each_line do |line|
      begin
        ActiveRecord::Base.connection().execute( line )
      rescue
        puts "WARNING: The database is inconsistent, some FOREIGN KEYs (aka CONSTRAINTS) can not be added!"
        puts "         please run    script/check_database    script to fix the data."
        raise IllegalMigrationNameError.new("migration failed due to inconsistent database")
      end
    end
  end

  def self.drop_constraint( table, count )
    for nr in (1..count)
      begin
        ActiveRecord::Base.connection().execute( "alter table #{table} drop FOREIGN KEY #{table}_ibfk_#{nr};" )
      rescue
      end
    end
  end

  def self.down
    drop_constraint("release_targets", 2)
  end
end
