module ProjectStatusControllerService
  class OpenSUSEUpstreamTarballURLFinder < AttribValuesFinder
    def self.call(packages)
      new(packages, 'openSUSE', 'UpstreamTarballURL').attribute_values
    end
  end
end
