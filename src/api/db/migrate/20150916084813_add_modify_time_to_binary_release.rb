class AddModifyTimeToBinaryRelease < ActiveRecord::Migration[4.2]
  def self.up
    add_column :binary_releases, :modify_time, :datetime

    BinaryRelease.where(operation: "modified").each do |br|
      added = BinaryRelease.where(operation: "added",
                                  repository_id: br.repository_id,
                                  binary_name: br.binary_name,
                                  binary_version: br.binary_version,
                                  binary_release: br.binary_release,
                                  binary_epoch: br.binary_epoch,
                                  binary_arch: br.binary_arch,
                                  medium: br.medium)
      unless added.length == 1
        Rails.logger.error "ERROR: Unique added entry belonging to modified entry not found: #{br.id}"
        next
      end
      added.first.modify_time = added.first.obsolete_time
      added.first.obsolete_time = nil
      added.first.save
    end
  end

  def self.down
    BinaryRelease.not.where(modify_time: nil).each do |br|
      added = BinaryRelease.where(operation: "added",
                                  repository_id: br.repository_id,
                                  binary_name: br.binary_name,
                                  binary_version: br.binary_version,
                                  binary_release: br.binary_release,
                                  binary_epoch: br.binary_epoch,
                                  binary_arch: br.binary_arch,
                                  medium: br.medium)
      unless added.length == 1
        Rails.logger.error "ERROR: Unique added entry belonging to modified entry not found: #{br.id}"
        next
      end
      added.first.obsolete_time = added.first.modify_time
      added.first.save
    end

    remove_column :binary_releases, :modify_time
  end
end
