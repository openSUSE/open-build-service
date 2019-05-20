module ObsFactory
  # this is not a Factory pattern, this is for openSUSE:Factory :/
  class DistributionStrategyFactory
    require 'open-uri'
    include ActiveModel::Model

    attr_accessor :project
    attr_accessor :staging_manager

    # String to pass as version to filter the openQA jobs
    #
    # @return [String] version parameter
    def openqa_version
      'Tumbleweed'
    end

    def openqa_group
      'openSUSE Tumbleweed'
    end

    #
    # Name of the project used as top-level for the staging projects and
    # the rings
    #
    # @return [String] project name
    def root_project_name
      project.name
    end

    def test_dvd_prefix
      'Test-DVD'
    end

    def totest_version_package
      '000product:openSUSE-cd-mini-x86_64'
    end

    def arch
      'x86_64'
    end

    def url_suffix
      'tumbleweed/iso'
    end

    def rings
      %w[Bootstrap MinimalX]
    end

    def repo_url
      'http://download.opensuse.org/tumbleweed/repo/oss/media.1/media'
    end

    def published_arch
      'i586'
    end

    # Version of the distribution used as ToTest
    #
    # @return [String] version string
    def totest_version
      d = Xmlhash.parse(Backend::Api::BuildResults::Binaries.files("#{project.name}:ToTest", 'images', 'local', totest_version_package))
      d.elements('binary') do |b|
        matchdata = /.*(Snapshot|Build)(.*)-Media\.iso$/.match(b['filename'])
        return matchdata[2] if matchdata
      end
    rescue
      nil
    end

    # Version of the published distribution
    #
    # @return [String] version string
    def published_version
      begin
        stream = URI.open(repo_url)
      rescue ::OpenURI::HTTPError
        return 'unknown'
      end

      stream.read[/openSUSE-(.*)-#{published_arch}-.*/, 1]
    end
  end
end
