# the data was stored at the wrong place, with the risk that it got overwritten.
class FixDevelpackagid < ActiveRecord::Migration
  # down and up are doing the same, just swapping the fields
  def self.up
      sql =<<-END_SQL
      SELECT id,develpackage_id FROM db_packages
      END_SQL

      list = Repository.find_by_sql sql
      result = []
      result << "UPDATE db_packages SET develpackage_id=NULL"
      list.each do |l|
        if not l.develpackage_id.nil?
          result << "UPDATE db_packages SET develpackage_id=#{l.id} where id=#{l.develpackage_id}"
        end
      end

      result.each do |r|
        self.connection.insert r
      end
  end

  def self.down
      sql =<<-END_SQL
      SELECT id,develpackage_id FROM db_packages
      END_SQL

      list = Repository.find_by_sql sql
      result = []
      result << "UPDATE db_packages SET develpackage_id=NULL"
      list.each do |l|
        if not l.develpackage_id.nil?
          result << "UPDATE db_packages SET develpackage_id=#{l.id} where id=#{l.develpackage_id}"
        end
      end

      result.each do |r|
        self.connection.insert r
      end
  end
end
