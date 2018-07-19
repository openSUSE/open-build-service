module ObsFactory

  class DistributionStrategyCasp < DistributionStrategyFactory

    def casp_version
      match = project.name.match(/^SUSE:SLE-12-SP.*CASP(\d*)/ )
      match[1]
    end

    def staging_manager
      'caasp-staging-managers'
    end

    def repo_url; end

    def openqa_version
      '3.0'
    end

    # Name of the ISO file by the given staging project tracked on openqa
    #
    # @return [String] file name
    def openqa_iso(project)
      project_iso(project)
    end

    # Name of the ISO file produced by the given staging project's Test-DVD
    #
    # Not part of the Strategy API, but useful for subclasses
    #
    # @return [String] file name
    def project_iso(project)
      arch = self.arch
      buildresult = Buildresult.find_hashed(project: project.name, package: "CAASP-dvd5-DVD-#{arch}",
                                            repository: 'images',
                                            view: 'binarylist')
      binaries = []
      # we get multiple architectures, but only one with binaries
      buildresult.elements('result') do |r|
        r['binarylist'].elements('binary') do |b|
          return b['filename'] if /\.iso$/ =~ b['filename']
        end
      end
      nil
    end

  end
end
