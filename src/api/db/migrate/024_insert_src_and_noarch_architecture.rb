class InsertSrcAndNoarchArchitecture < ActiveRecord::Migration


  def self.up
    Architecture.create :name => 'src'
    Architecture.create :name => 'noarch'
  end


  def self.down
    Architecture.find_by_name( 'src' ).destroy_without_callbacks
    Architecture.find_by_name( 'noarch' ).destroy_without_callbacks
  end


end
