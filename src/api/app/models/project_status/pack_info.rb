module ProjectStatus
  class PackInfo
    attr_accessor :bp, :project
    attr_accessor :srcmd5, :verifymd5, :changesmd5, :maxmtime, :error, :links_to
    attr_reader :name, :package_id
    attr_accessor :develpack
    attr_accessor :failed_comment, :upstream_version, :upstream_url, :declined_request
    attr_reader :version, :release, :versiontime
    attr_reader :failed, :groups, :persons

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
      @failed = Hash.new

      # only set from status controller
      @groups = Array.new
      @persons = Array.new
    end

    def add_person(login, role)
      @persons << [login, role]
    end

    def add_group(title, role)
      @groups << [title, role]
    end

    def to_xml(options = {})
      # return packages not having sources
      return if srcmd5.blank?
      xml = options[:builder] ||= Builder::XmlMarkup.new(indent: options[:indent])
      opts = {
        project:    project,
        name:       name,
        version:    version,
        srcmd5:     srcmd5,
        changesmd5: changesmd5,
        maxmtime:   maxmtime,
        release:    release
      }
      unless verifymd5.blank? || verifymd5 == srcmd5
        opts[:verifymd5] = verifymd5
      end
      xml.package(opts) do
        fails.each do |repository, _architecture, time, md5|
          xml.failure(repo: repository, time: time, srcmd5: md5)
        end
        if develpack
          xml.develpack(proj: develpack.project, pack: develpack.name) do
            develpack.to_xml(builder: xml)
          end
        end

        relationships_to_xml(xml, :persons, :person, :userid)
        relationships_to_xml(xml, :groups, :group, :groupid)

        xml.error(error) if error
        xml.link(project: links_to.project, package: links_to.name) if links_to
      end
    end

    def relationships_to_xml(builder, arrayname, elementname, tag)
      arr = send(arrayname)
      return if arr.empty?
      builder.send(arrayname) do
        arr.each do |element, role_name|
          builder.send(elementname, tag => element, :role => role_name)
        end
      end
    end

    def set_versrel(versrel, time)
      return if @versiontime && @versiontime > time
      versrel = versrel.split('-')
      @versiontime = time
      @version = versrel[0..-2].join('-')
      @release = versrel[-1]
    end

    def failure(repo, arch, time, md5)
      # we only track the first failure time but latest md5 returned
      if @failed.has_key? repo
        time = [@failed[repo][0], time].min
      end
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
