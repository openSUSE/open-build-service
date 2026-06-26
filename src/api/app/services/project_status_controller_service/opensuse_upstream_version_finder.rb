module ProjectStatusControllerService
  class OpenSUSEUpstreamVersionFinder < AttribValuesFinder
    def self.call(packages)
      new(packages, 'openSUSE', 'UpstreamVersion').attribute_values
    end
  end
end
