class DropRemoteDistributions < ActiveRecord::Migration
  def up
    Distribution.all.each do |d|
      unless Project.find_by_name d.project
        # project does not exist, drop it
        d.destroy
      end
    end
  end

  def down
    # not restorable
  end
end
