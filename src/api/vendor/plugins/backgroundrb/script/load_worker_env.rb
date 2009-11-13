#!/usr/bin/env ruby

RAILS_HOME = File.expand_path(File.join(File.dirname(__FILE__),".."))
BDRB_HOME = File.join(RAILS_HOME,"vendor","plugins","backgroundrb")

["server","server/lib","lib","lib/backgroundrb"].each { |x| $LOAD_PATH.unshift(BDRB_HOME + "/#{x}")}

$LOAD_PATH.unshift(File.join(RAILS_HOME,"lib","workers"))

require "yaml"
require "erb"
require "logger"
require "optparse"
require "bdrb_config"
require RAILS_HOME + "/config/boot"
require "active_support"

BDRB_CONFIG = BackgrounDRb::Config.read_config("#{RAILS_HOME}/config/backgroundrb.yml")

if !(::Packet::WorkerRunner::WORKER_OPTIONS[:worker_env] == false)
  require RAILS_HOME + "/config/environment"
  if (Object.const_defined?(:Rails) && (!Rails.respond_to?(:version) || Rails.version < "2.2.2")) ||
     (Object.const_defined?(:RAILS_GEM_VERSION) && RAILS_GEM_VERSION < "2.2.2")
    ActiveRecord::Base.allow_concurrency = true
  end
end
require "backgroundrb_server"

