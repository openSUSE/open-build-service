require 'ostruct'
require 'digest/md5'

include ActionView::Helpers::NumberHelper
include ObjectSpace

class LinkInfo
  attr_accessor :project
  attr_accessor :package
  attr_accessor :targetmd5
end

class PackInfo
  attr_accessor :devel_project, :devel_package
  attr_accessor :srcmd5, :verifymd5, :changesmd5, :maxmtime, :error, :link
  attr_reader :name, :project, :key, :package_id
  attr_accessor :develpack
  attr_accessor :failed_comment, :upstream_version, :upstream_url, :declined_request
  attr_reader :version, :release, :versiontime
  attr_reader :failed

  def initialize(db_pack, project_name)
    @project = project_name
    @name = db_pack.name
    # we don't store the full package object as it can become huge
    @package_id = db_pack.id
    @key = @project + "/" + name
    @devel_project = nil
    @devel_package = nil
    @link = LinkInfo.new
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
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    opts = { :project => project,
             :name => name,
             :version => version,
             :srcmd5 => srcmd5,
             :changesmd5 => changesmd5,
             :maxmtime => maxmtime,
             :release => release }
    unless verifymd5.blank? or verifymd5 == srcmd5
      opts[:verifymd5] = verifymd5
    end
    xml.package(opts) do
      self.fails.each do |repo, tuple|
        xml.failure(:repo => repo, :time => tuple[0], :srcmd5 => tuple[1])
      end
      if develpack
        xml.develpack(:proj => devel_project, :pack => devel_package) do
          develpack.to_xml(:builder => xml)
        end
      end
      
      xml.persons do
        @persons.each do |ulogin, role_name|
          xml.person(:userid => ulogin, :role => role_name)
        end
      end unless @persons.empty?
      xml.groups do
        @groups.each do |gtitle, rolename|
          xml.group(:groupid => gtitle, :role => rolename)
        end
      end unless @groups.empty?

      if @error then
        xml.error(error)
      end
      if @link.project
        xml.link(:project => @link.project, :package => @link.package, :targetmd5 => @link.targetmd5)
      end
    end
  end

  def set_versrel(versrel, time)
    return if @versiontime and @versiontime > time
    versrel = versrel.split('-')
    @versiontime = time
    @version = versrel[0..-2].join('-')
    @release = versrel[-1]
  end

  def failure(repo, arch, time, md5)
    Rails.logger.debug "failure #{repo} #{arch} #{time} #{md5}"
    # we only track the first failure time but latest md5 returned
    if @failed.has_key? repo
      time = [@failed[repo][0], time].min
    end
    @failed[repo] = [time, arch, md5]
  end

  def fails
    ret = Array.new
    @failed.each do |repo, tuple|
      # repo, arch, time, md5
      ret << [repo, tuple[1], tuple[0], tuple[2]]
    end
    return ret
  end

end

class ProjectStatusHelper

  def self.get_xml(uri)
    key = Digest::MD5.hexdigest(uri)
    d = Rails.cache.fetch(key, :expires_in => 2.hours) do
      Suse::Backend.get(uri).body
    end
    Xmlhash.parse(d)
  end

  def self.check_md5(proj, packages, mypackages)
    uri = '/getprojpack?project=%s&withsrcmd5=1&ignoredisable=1' % CGI.escape(proj)
    packages.each do |package|
      uri += "&package=" + CGI.escape(package.name)
    end
    data = get_xml(uri)

    data.get('project').elements('package') do |p|

      packname = p['name']
      key = proj + "/" + packname
      next unless mypackages.has_key?(key)
      mypackages[key].srcmd5 = p['srcmd5']
      if p['verifymd5']
        mypackages[key].verifymd5 = p['verifymd5']
      end
      p.elements('linked') do |l|
        mypackages[key].link.project = l['project']
        mypackages[key].link.package = l['package']
        break # the first link will do
      end
      p.elements('error') do |e|
        mypackages[key].error = e
        break
      end
      cmd5, mtime = Rails.cache.fetch("change-data-%s" % p['srcmd5']) do
        begin
          directory = Directory.hashed(project: proj, package: packname, expand: 1)
        rescue ActiveXML::Transport::Error
          directory = nil
        end
        changesfile="%s.changes" % packname
        md5 = ''
        mtime = 0
        directory.elements('entry') do |e|
          if e['name'] == changesfile
            md5 = e['md5']
          end
          mtime = [mtime, Integer(e['mtime'])].max
        end if directory
        [md5, mtime]
      end
      mypackages[key].changesmd5 = cmd5 unless cmd5.empty?
      mypackages[key].maxmtime = mtime unless mtime == 0
    end if data
  end

  def self.update_projpack(proj, mypackages)
    packages = []
    mypackages.each do |key, package|
      if package.project == proj
        packages << package
      end
    end

    check_md5(proj, packages, mypackages)
  end

  # parse the jobhistory and put the result in a format we can cache
  def self.parse_jobhistory(dname, repo, arch, packagequery)

    uri = '/build/%s/%s/%s/_jobhistory?code=lastfailures' % [CGI.escape(dname), CGI.escape(repo), arch]
    uri += packagequery

    ret = []
    d = Suse::Backend.get(uri).body
    unless d.blank?
      data = Xmlhash.parse(d)

      data.elements('jobhist') do |p|
        line = {'name' => p['package'],
                'code' => p['code'],
                'versrel' => p['versrel'],
                'srcmd5' => p['srcmd5']}

        line['key'] = dname + "/" + p['package']
        begin
          line['readytime'] = Integer(p['readytime'])
        rescue
          line['readytime'] = 0
        end
        ret << line
      end
    end
    ret
  end

  def self.update_jobhistory(targetproj, dbproj, mypackages)
    prjpacks = Hash.new
    dname = dbproj.name
    mypackages.each_value do |package|
      if package.project == dname
        prjpacks[package.name] = package
      end
    end

    packagequery = prjpacks.keys.map { |name| "&package=" + CGI.escape(name) }.join

    dbproj.repositories_linking_project(targetproj).each do |r|
      repo = r['name']
      r.elements('arch') do |arch|

        cachekey = "history#{dbproj.cache_key}#{repo}#{arch}"
        jobhistory = Rails.cache.fetch(cachekey, expires_in: 30.minutes) do
          parse_jobhistory(dname, repo, arch, packagequery)
        end
        jobhistory.each do |p|
          pkg = mypackages[p['key']]
          next unless pkg

          pkg.set_versrel(p['versrel'], p['readytime'])
          pkg.failure(repo, arch, p['readytime'], p['srcmd5']) if p['code'] == "failed"
        end
      end
    end
  end

  def self.add_recursively(mypackages, projects, dbpack)
    projects[dbpack.db_project_id] ||= Project.find(dbpack.db_project_id).name
    pack = PackInfo.new(dbpack, projects[dbpack.db_project_id])
    return if mypackages.has_key? pack.key

    if dbpack.develpackage
      pack.devel_package = dbpack.develpackage.name
      pid = dbpack.develpackage.db_project_id
      projects[pid] ||= dbpack.develpackage.project.name
      pack.devel_project = projects[pid]
      add_recursively(mypackages, projects, dbpack.develpackage)
    end
    mypackages[pack.key] = pack
  end

  def self.move_devel_package(mypackages, key)
    return unless mypackages.has_key? key

    pack = mypackages[key]
    return unless pack.devel_project

    newkey = pack.devel_project + "/" + pack.devel_package
    return unless mypackages.has_key? newkey
    develpack = mypackages[newkey]
    pack.develpack = develpack
    key = develpack.project + "/" + develpack.name
    # recursion for the devel packages
    move_devel_package(mypackages, key)
  end

  def self.filter_by_package_name(name)
    #return (name =~ /perl-C/)
    return true
  end

  def self.calc_status(dbproj, opts = {})
    mypackages = Hash.new

    if !dbproj
      puts "invalid project " + proj
      return mypackages
    end
    projects = Hash.new

    x = Benchmark.ms do
      projects[dbproj.id] = dbproj.name
      dbproj.packages.select([:id, :name, :db_project_id, :develpackage_id]).includes(:develpackage).load.each do |dbpack|
        next unless filter_by_package_name(dbpack.name)
        add_recursively(mypackages, projects, dbpack)
      end
    end
    logger.debug "TIMEX #{x}"

    x = Benchmark.ms do
      projects.each do |id, name|
        if !opts[:pure_project] || id == dbproj.id
          update_jobhistory(dbproj, Project.find(id), mypackages)
        end
        update_projpack(name, mypackages)
      end
    end
    logger.debug "TIMEY #{x}"

    x = Benchmark.ms do
      dbproj.packages.each do |dbpack|
        next unless filter_by_package_name(dbpack.name)
        key = dbproj.name + "/" + dbpack.name
        move_devel_package(mypackages, key)
      end
    end
    logger.debug "TIMEZ #{x}"

    links = Hash.new
    x = Benchmark.ms do
      # find links
      mypackages.values.each do |package|
        if package.project == dbproj.name and package.link.project
          links[package.link.project] ||= Array.new
          links[package.link.project] << package.link.package
        end
      end

    end
    logger.debug "TIME0 #{x}"

    x = Benchmark.ms do
      links.each do |proj, packages|
        tocheck = Array.new
        packages.each do |name|
          pack = Package.find_by_project_and_name(proj, name)
          next unless pack # broken link
          pack = PackInfo.new(pack, proj)
          next if mypackages.has_key? pack.key
          tocheck << pack
          mypackages[pack.key] = pack
        end
        check_md5(proj, tocheck, mypackages) unless tocheck.empty?
      end
    end
    logger.debug "TIME1 #{x}"
    x = Benchmark.ms do
      mypackages.each_value do |package|
        if package.project == dbproj.name and package.link.project
          newkey = package.link.project + "/" + package.link.package
          # broken links
          next unless mypackages.has_key? newkey
          package.link.targetmd5 = mypackages[newkey].verifymd5
          package.link.targetmd5 ||= mypackages[newkey].srcmd5
        end
      end
    end

    logger.debug "TIME2 #{x}"

    # cleanup
    mypackages.keys.each do |key|
      mypackages.delete(key) if mypackages[key].project != dbproj.name
    end

    return mypackages
  end

  def self.logger
    Rails.logger
  end

end

module StatusHelper

  def self.resample(values, samples = 400)
    values.sort! { |a, b| a[0] <=> b[0] }

    result = Array.new
    return result unless values.length > 0

    lastvalue = 0
    now = values[0][0]
    samplerate = (values[-1][0] - now) / samples

    index = 0

    1.upto(samples) do |i|
      value = 0.0
      count = 0
      while index < values.length && values[index][0] < now + samplerate
        value += values[index][1]
        index += 1
        count += 1
      end
      if count > 0
        value = value / count
      else
        value = lastvalue
      end
      result << [now + samplerate / 2, value]
      now += samplerate
      lastvalue = value
    end

    return result
  end

end
