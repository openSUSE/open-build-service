module ArchitecturesControllerService
  class ArchitectureUpdater
    def initialize(params)
      @archs = params.require(:archs).permit!
      @all_valid = false
    end

    def call
      @all_valid = @archs.to_h.map do |name, value|
        arch = Architecture.find_by(name: name)
        arch.available = value
        arch.save
      end

      self
    end

    def valid?
      @all_valid.all?
    end
  end
end
