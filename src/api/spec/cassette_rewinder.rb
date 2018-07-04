require 'set'
USED_CASSETTES = Set.new

module CassetteReporter
  def insert_cassette(name, options = {})
    USED_CASSETTES << VCR::Cassette.new(name, options).file
    super
  end
end
VCR.extend(CassetteReporter)
