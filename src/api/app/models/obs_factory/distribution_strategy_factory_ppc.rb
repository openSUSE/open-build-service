module ObsFactory

  # PowerPC to Factory Diff
  class DistributionStrategyFactoryPPC < DistributionStrategyFactory
    def root_project_name
      "openSUSE:Factory"
    end

    def totest_version_file
      'images/local/000product:openSUSE-cd-mini-ppc64le'
    end

    def arch
      'ppc64le'
    end

    def url_suffix
      'ports/ppc/factory'
    end

    def openqa_group
      'openSUSE Tumbleweed PowerPC'
    end

    def repo_url
      'http://download.opensuse.org/ports/ppc/factory/repo/oss/media.1/build'
    end

    def published_arch
      "ppc64le"
    end
  end
end
