#!/usr/bin/env ruby.ruby2.4

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'delayed/command'
require 'workers/import_requests.rb'
Delayed::Command.new(ARGV).daemonize
