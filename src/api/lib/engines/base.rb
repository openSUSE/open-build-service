# frozen_string_literal: true
module OBSEngine
  # base class for all engine hooks
  class Base
    # implement this function to patch the routes
    def self.mount_it; end
  end

  def self.load_engines
    dirname = File.dirname(__FILE__)
    Dir.foreach(dirname) do |filename|
      next unless filename =~ %r{.rb}
      # ignore ourselves
      next if filename == File.basename(__FILE__)
      require File.join(dirname, filename)
    end
  end
end
