#!/usr/bin/ruby.ruby2.5
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))

output = %x(service obsapidelayed status | grep "active")

raise StandardError, 'obsapidelayed service is down!' if output.blank?
