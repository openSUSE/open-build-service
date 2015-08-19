class MoveEnabledArchsToDistro < ActiveRecord::Migration
  def up
    Distribution.all.each do |d|
      Architecture.where( recommended: true ).each do |a|
        d.architectures << a
      end
      d.save!
    end

    remove_column :architectures, :recommended
  end

  def down
    add_column :architectures, :recommended, :boolean
  end
end
