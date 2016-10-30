require 'ostruct'
require 'digest/md5'

include ActionView::Helpers::NumberHelper
include ObjectSpace

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
    opts = { project:    project,
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
      fails.each do |repo, tuple|
        xml.failure(repo: repo, time: tuple[0], srcmd5: tuple[1])
      end
      if develpack
        xml.develpack(proj: develpack.project, pack: develpack.name) do
          develpack.to_xml(builder: xml)
        end
      end

      relationships_to_xml(xml, :persons, :person, :userid)
      relationships_to_xml(xml, :groups, :group, :groupid)

      xml.error(error) if @error
      xml.link(project: @links_to.project, package: @links_to.name) if @links_to
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

class ProjectStatusCalculator
  def check_md5(packages)
    # remap
    ph = {}
    packages.each { |p| ph[p.package_id] = p }
    packages = Package.where(id: ph.keys).includes(:backend_package).references(:backend_packages)
    packages.each do |p|
      obj = ph[p.id]
      obj.bp = p.backend_package
      obj.srcmd5 = obj.bp.srcmd5
      obj.verifymd5 = obj.bp.verifymd5
      obj.error = obj.bp.error
      obj.links_to = obj.bp.links_to_id
      obj.changesmd5 = obj.bp.changesmd5
      obj.maxmtime = obj.bp.maxmtime.to_i
    end
  end

  # parse the jobhistory and put the result in a format we can cache
  def parse_jobhistory(dname, repo, arch)
    uri = '/build/%s/%s/%s/_jobhistory?code=lastfailures' % [CGI.escape(dname), CGI.escape(repo), arch]

    ret = []
    d = Suse::Backend.get(uri).body

    return [] if d.blank?

    data = Xmlhash.parse(d)

    data.elements('jobhist') do |p|
        line = {
          'name'      => p['package'],
          'code'      => p['code'],
          'versrel'   => p['versrel'],
          'verifymd5' => p['verifymd5']
        }

        if p.has_key?('readytime')
            if p['readytime'].respond_to?(:to_i)
                line['readytime'] = p['readytime'].to_i
            else
                line['readytime'] = 0
            end
        else
            line['readytime'] = 0
        end
        ret << line
    end
    ret
  end

  def update_jobhistory(proj, mypackages)
    prjpacks = Hash.new
    dname = proj.name
    mypackages.each_value do |package|
      if package.project == dname
        prjpacks[package.name] = package
      end
    end

    proj.repositories_linking_project(@dbproj).each do |r|
      repo = r['name']
      r.elements('arch') do |arch|
        cachekey = "history2#{proj.cache_key}#{repo}#{arch}"
        jobhistory = Rails.cache.fetch(cachekey, expires_in: 30.minutes) do
          parse_jobhistory(dname, repo, arch)
        end
        jobhistory.each do |p|
          pkg = prjpacks[p['name']]
          next unless pkg

          pkg.set_versrel(p['versrel'], p['readytime'])
          pkg.failure(repo, arch, p['readytime'], p['verifymd5']) if p['code'] == "failed"
        end
      end
    end
  end

  def add_recursively(mypackages, dbpack)
    return if mypackages.has_key? dbpack.id
    pack = PackInfo.new(dbpack)

    if dbpack.develpackage
      add_recursively(mypackages, dbpack.develpackage)
      pack.develpack = mypackages[dbpack.develpackage_id]
    end
    mypackages[pack.package_id] = pack
  end

  def initialize(dbproj)
    @dbproj = dbproj
  end

  def calc_status(opts = {})
    mypackages = Hash.new

    if !@dbproj
      return mypackages
    end

    @dbproj.packages.select([:id, :name, :project_id, :develpackage_id]).includes(:develpackage).load.each do |dbpack|
      add_recursively(mypackages, dbpack)
    end

    check_md5(mypackages.values)

    links = Array.new
    # find links
    mypackages.each_value.each do |package|
      if package.project == @dbproj.name && package.links_to_id
        links << package.links_to_id
      end
    end
    links = Package.where(id: links).includes(:project).to_a

    tocheck = Array.new
    links.each do |pack|
      pack = PackInfo.new(pack)
      next if mypackages.has_key? pack.key
      tocheck << pack
      mypackages[pack.key] = pack
    end
    check_md5(tocheck)

    list = Project.joins(:packages).where(packages: {id: mypackages.keys}).pluck("projects.id as pid, projects.name, packages.id")
    projects = Hash.new
    list.each do |pid, pname, id|
      obj = mypackages[id]
      obj.project = pname
      if obj.links_to
        obj.links_to = mypackages[obj.links_to]
      end
      projects[pid] = pname
    end

    projects.each do |id, _|
      if !opts[:pure_project] || id == @dbproj.id
        update_jobhistory(Project.find(id), mypackages)
      end
    end

    # cleanup
    mypackages.each_key do |key|
      mypackages.delete(key) if mypackages[key].project != @dbproj.name
    end

    mypackages
  end

  def logger
    Rails.logger
  end
end
