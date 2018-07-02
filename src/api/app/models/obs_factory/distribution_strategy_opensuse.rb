module ObsFactory

  # this class tracks the differences between Factory and the upcoming release
  class DistributionStrategyOpenSUSE < DistributionStrategyFactory
    def opensuse_version
      # Remove the "openSUSE:" part
      project.name[9..-1]
    end

    def opensuse_leap_version
      # Remove the "openSUSE:Leap:" part
      project.name[14..-1]
    end

    def openqa_version
      # Only use major version to find the openSUSE Leap job group since we use
      # the same job group for the whole codestream
      opensuse_leap_version[0..1]
    end

    def openqa_group
      "openSUSE Leap #{opensuse_leap_version}"
    end

    def repo_url
      "http://download.opensuse.org/distribution/leap/#{opensuse_leap_version}/repo/oss/media.1/media"
    end

    def url_suffix
      "distribution/leap/#{opensuse_leap_version}/iso"
    end

    def openqa_iso_prefix
      "openSUSE-#{opensuse_version}-Staging"
    end

    def published_arch
      'x86_64'
    end

    def test_dvd_prefix
      '000product:openSUSE-dvd5-dvd'
    end

    def totest_version_file
      'images/local/000product:openSUSE-cd-mini-x86_64'
    end

    # Version of the published distribution
    #
    # @return [String] version string
    def published_version
      begin
        f = open(repo_url)
      rescue OpenURI::HTTPError => e
        return 'unknown'
      end
      matchdata = %r{openSUSE-#{opensuse_leap_version}-#{published_arch}-Build(.*)}.match(f.read)
      matchdata[1]
    end

    # URL parameter for Leap
    def openqa_filter(project)
      return "match=#{opensuse_leap_version}:S:#{project.letter}"
    end

  end
end
