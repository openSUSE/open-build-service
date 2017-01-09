class WriteConfigurationJob
  def initialize
  end

  def perform
    @configuration = ::Configuration.first
    @configuration.save!
  end
end
