class InsertSrcAndNoarchArchitecture < ActiveRecord::Migration


  def self.up
    Architecture.create :name => 'src'
    Architecture.create :name => 'noarch'
  end


  def self.down
    for a in %w|src noarch| do
      arch = Architecture.find_by_name(a)
      arch.destroy_without_callbacks if arch
    end 
  end


end
