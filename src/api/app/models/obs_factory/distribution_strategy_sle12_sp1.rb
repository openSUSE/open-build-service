module ObsFactory
  class DistributionStrategySLE12SP1 < DistributionStrategyFactory
    def sp_version
      match = project.name.match(/SLE-12-(.*):GA/)
      match[1]
    end

    def staging_manager
      'sle-staging-managers'
    end

    def repo_url
      'http://download.opensuse.org/distribution/13.2/repo/oss/media.1/build'
    end

    def openqa_version
      "SLES 12 #{sp_version}"
    end

    # Name of the ISO file by the given staging project tracked on openqa
    #
    # @return [String] file name
    def openqa_iso(project)
      ending = project_iso(project)
      return if ending.nil?
      ending.gsub!(/.*-Build/, '')
      "SLE12-#{sp_version}-Staging:#{project.letter}-Test-Server-DVD-#{arch}-Build#{project.letter}.#{ending}"
    end
  end
end
