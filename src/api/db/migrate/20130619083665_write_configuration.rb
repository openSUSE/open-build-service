require 'delayed_job'
require File.join(Rails.root, 'lib/workers/write_configuration.rb')

class WriteConfiguration < ActiveRecord::Migration

  def self.up
    Delayed::Job.enqueue WriteConfigurationJob.new
  end

  def self.down
  end

end

