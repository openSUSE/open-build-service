require 'set'
USED_CASSETTES = Set.new

module CassetteReporter
  def insert_cassette(name, options = {})
    USED_CASSETTES << VCR::Cassette.new(name, options).file
    super
  end
end
VCR.extend(CassetteReporter)

# delete all unecessary cassettes
RSpec.configure do |config|
  config.after(:suite) do
    files = (Dir[File.join(Rails.root, 'spec', 'cassettes', '**', '*.yml')] - USED_CASSETTES.to_a)
    files.each { |v| File.delete(v) } unless files.empty?
  end
end
