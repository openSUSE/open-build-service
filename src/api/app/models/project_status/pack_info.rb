module ProjectStatus
  class PackInfo
    attr_accessor :backend_package, :project, :links_to, :develpack, :failed_comment, :upstream_version, :upstream_url, :declined_request
    attr_reader :name, :package_id, :version, :release, :versiontime, :failed, :groups, :persons
    delegate :srcmd5, :verifymd5, :changesmd5, :maxmtime, :error, :links_to_id, to: :backend_package

    def initialize(db_pack)
      @name = db_pack.name
      # we don't store the full package object as it can become huge
      @package_id = db_pack.id
      @links_to = nil
      @version = nil
      @release = nil
      # we avoid going back in versions by avoiding going back in time
      # the last built version wins (repos may have different versions)
      @versiontime = nil
      @failed = {}

      # only set from status controller
      @groups = []
      @persons = []
    end

    def add_person(login, role)
      @persons << [login, role]
    end

    def add_group(title, role)
      @groups << [title, role]
    end

    def header
      options = {
        project:    project,
        name:       name,
        version:    version,
        srcmd5:     srcmd5,
        changesmd5: changesmd5,
        maxmtime:   maxmtime,
        release:    release
      }
      unless verifymd5.blank? || verifymd5 == srcmd5
        options[:verifymd5] = verifymd5
      end
      options
    end

    def set_versrel(versrel, time)
      return if @versiontime && @versiontime.to_i > time.to_i
      versrel = versrel.split('-')
      @versiontime = time
      @version = versrel[0..-2].join('-')
      @release = versrel[-1]
    end

    def failure(repo, arch, time, md5)
      # we only track the first failure time but latest md5 returned
      time = [@failed[repo][0], time].min if @failed.key? repo
      @failed[repo] = [time, arch, md5]
    end

    def fails
      @failed.map do |repo, tuple|
        # repo, arch, time, md5
        [repo, tuple[1], tuple[0], tuple[2]]
      end
    end
  end
end
