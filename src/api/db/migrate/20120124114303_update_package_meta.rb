require 'delayed_job'
require File.join(Rails.root, 'lib/workers/update_package_meta_job.rb')

class UpdatePackageMeta < ActiveRecord::Migration
  def self.up
    Delayed::Job.enqueue UpdatePackageMetaJob.new
  end

  def self.down
  end
end
