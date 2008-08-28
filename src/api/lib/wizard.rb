class Wizard
  class << self
    def guess_version(name, tarball)
        if tarball =~ /^#{name}-(.*)\.tar\.(gz|bz2)$/i
          return $1
        elsif tarball =~ /.*-([0-9\.]*)\.tar\.(gz|bz2)$/
          return $1
        end
        return nil
    end
  end
end

# vim:et:ts=2:sw=2
