class AddSelectableFlagForArchitectures < ActiveRecord::Migration


  def self.up
    add_column :architectures, :selectable, :boolean, :default => false

    # make i586 selectable
    if arch = Architecture.find_by_name( 'i586' )
      arch.selectable = true
      arch.save
    end
    # make x86_64 selectable
    if arch = Architecture.find_by_name( 'x86_64' )
      arch.selectable = true
      arch.save
    end
  end


  def self.down
    remove_column :architectures, :selectable
  end


end

