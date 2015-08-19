require 'delayed_job'
require File.join(Rails.root, 'lib/workers/import_requests.rb')

class ImportRequestsDelayed < ActiveRecord::Migration

  def self.up
    Delayed::Job.enqueue ImportRequestsDelayedJob.new
  end

  def self.down
  end

end

