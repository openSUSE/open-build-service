# frozen_string_literal: true

require 'delayed_job'
require File.join(Rails.root, 'app/jobs/update_package_meta_job.rb')

class AddChannelIndex < ActiveRecord::Migration[4.2]
  def self.up
    # broken db? better parse again everything
    Channel.all.destroy_all

    add_index :channels, [:package_id], unique: true, name: 'index_unique'

    # trigger reparsing of all channels in delayed job
    PackageKind.all.where(kind: 'channel').each { |pk| BackendPackage.where(package_id: pk.package).delete_all }
    Delayed::Job.enqueue UpdatePackageMetaJob.new
  end

  def self.down
    remove_index :channels, name: 'index_unique'
  end
end
