#!/usr/bin/env ruby.ruby2.4

require 'bundler'

# This script retrieves all the possible rubygem package names of the
# rubygem dependencies needed to be included to create an OBS major
# release.
#
# For each rubygem it will create two entries.
#
# For example, for rubygem-activerecord-5.1.0:
# rubygem-activerecord
# rubygem-activerecord-5_1
#
# For example, for phantomjs-2.2.1:
# rubygem-phantomjs
# rubygem-phantomjs-2_2

Bundler.definition.specs_for([:default, :production, :assets]).any? do |s|
  min_version = s.version.to_s.split(/\./)[0..1].join('_')
  print "rubygem-#{s.name} rubygem-#{s.name}-#{min_version} "
end
