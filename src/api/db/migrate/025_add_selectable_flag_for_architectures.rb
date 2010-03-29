class AddSelectableFlagForArchitectures < ActiveRecord::Migration


  def self.up
    add_column :architectures, :selectable, :boolean, :default => false

    # make i586 selectable
    arch = Architecture.find_by_name( 'i586' )
    if arch
      arch.selectable = true
      arch.save
    end
    # make x86_64 selectable
    arch = Architecture.find_by_name( 'x86_64' )
    if arch
      arch.selectable = true
      arch.save
    end
  end


  def self.down
    remove_column :architectures, :selectable
  end


end

