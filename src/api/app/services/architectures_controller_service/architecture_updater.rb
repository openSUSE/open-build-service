module ArchitecturesControllerService
  class ArchitectureUpdater
    def initialize(archs)
      @archs = archs
      @all_valid = true
    end

    def call
      @archs.each do |name, value|
        arch = Architecture.find_by(name: name)
        arch.available = value
        @all_valid &&= arch.save
      end
      self
    end

    def valid?
      @all_valid
    end
  end
end
