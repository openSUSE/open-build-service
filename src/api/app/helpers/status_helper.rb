require 'ostruct'
require 'digest/md5'

include ActionView::Helpers::NumberHelper
include ObjectSpace

class LinkInfo
  attr_accessor :project
  attr_accessor :package
  attr_accessor :targetmd5
end

class BuildInfo

  attr_reader :version, :release, :versiontime
  attr_reader :failed

  def initialize
    @failed = Hash.new
    @last_success = Hash.new
    @version = nil
    @release = nil
    # we avoid going back in versions by avoiding going back in time
    # the last built version wins (repos may have different versions)
    @versiontime = nil

  end

  def success(reponame, time, md5)
    # try to remember last success
    if @last_success.has_key? reponame
      return if @last_success[reponame][0] > time
    end
    @last_success[reponame] = [time, md5]
  end

  def failure(reponame, time, md5)
    # we only track the first failure time but latest md5 returned
    if @failed.has_key? reponame
      time = @failed[reponame][0]
    end
    @failed[reponame] = [time, md5]
  end

  def fails
    ret = Hash.new
    @failed.each do |repo,tuple|
      ls = begin @last_success[repo][0] rescue 0 end
      if ls < tuple[0]
	ret[repo] = tuple
      end
    end
    return ret
  end

  def set_version(version, release, time)
    return if @versiontime and @versiontime > time
    @versiontime = time
    @version = version
    @release = release
  end

  def merge(bi)
    set_version(bi.version, bi.release, bi.versiontime)
    bi.failed.each do |rep, tuple|
      failure(rep, tuple[0], tuple[1])
    end
  end
end

class PackInfo
  attr_accessor :devel_project, :devel_package
  attr_accessor :srcmd5, :verifymd5, :changesmd5, :maxmtime, :error, :link
  attr_reader :name, :project, :key
  attr_accessor :develpack
  attr_accessor :buildinfo

  def initialize(db_pack)
    @project = db_pack.project.name
    @name = db_pack.name
    # we don't store the full package object as it can become huge
    @db_pack_id = db_pack.id
    @key = @project + "/" + name
    @devel_project = nil
    @devel_package = nil
    @link = LinkInfo.new
    @buildinfo = nil
  end

  def to_xml(options = {})
    # return packages not having sources
    return if srcmd5.blank?
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    version = nil
    release = nil
    if buildinfo
      version = buildinfo.version
      release = buildinfo.release
    end
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
      buildinfo.fails.each do |repo,tuple|
        xml.failure(:repo => repo, :time => tuple[0], :srcmd5 => tuple[1] )
      end if buildinfo
      if develpack
        xml.develpack(:proj => devel_project, :pack => devel_package) do
          develpack.to_xml(:builder => xml)
        end
      end
      db_pack = Package.find(@db_pack_id)
      xml.persons do
        db_pack.each_user do |ulogin, role_name|
          xml.person( :userid => ulogin, :role => role_name )
        end
      end unless db_pack.package_user_role_relationships.empty?
      xml.groups do
        db_pack.each_group do |gtitle, rolename|
          xml.group( :groupid => gtitle, :role => rolename )
        end
      end unless db_pack.package_group_role_relationships.empty?

      if @error then xml.error(error) end
      if @link.project
        xml.link(:project => @link.project, :package => @link.package, :targetmd5 => @link.targetmd5)
      end
    end
  end

  def add_buildinfo(bi)
    unless @buildinfo
      @buildinfo = bi
      return
    end
    @buildinfo.merge(bi)
  end
end

class ProjectStatusHelper

  def self.get_xml(backend, uri)
    key = Digest::MD5.hexdigest(uri)
    d = Rails.cache.fetch(key, :expires_in => 2.hours) do
      backend.direct_http( URI(uri), :timeout => 1000 )
    end
    ActiveXML::Node.new(d)
  end

  def self.check_md5(proj, backend, packages, mypackages)
    uri = '/getprojpack?project=%s&withsrcmd5=1&ignoredisable=1' % CGI.escape(proj)
    packages.each do |package|
      uri += "&package=" + CGI.escape(package.name)
    end
    data = get_xml(backend, uri)
    data.each('/projpack/project/package') do |p|
      packname = p.value('name')
      key = proj + "/" + packname
      next unless mypackages.has_key?(key)
      mypackages[key].srcmd5 = p.value('srcmd5')
      if p.value('verifymd5')
        mypackages[key].verifymd5 = p.value('verifymd5')
      end
      p.each('linked') do |l|
	mypackages[key].link.project = l.value('project')
	mypackages[key].link.package = l.value('package')
        break # the first link will do
      end
      p.each('error') do |e|
	mypackages[key].error = e.text
        break
      end
      cmd5, mtime = Rails.cache.fetch("change-data-%s" % p.value('srcmd5')) do
        begin
          directory = Directory.find(:project => proj, :package => packname, :expand => 1)
        rescue ActiveXML::Transport::Error
          directory = nil
        end
        changesfile="%s.changes" % packname
        md5 = ''
        mtime = 0
        directory.each_entry do |e|
          if e.value(:name) == changesfile
            md5 = e.value(:md5) 
          end
          mtime = [mtime, Integer(e.value(:mtime))].max
        end if directory
        [md5, mtime]
      end
      mypackages[key].changesmd5 = cmd5 unless cmd5.empty?
      mypackages[key].maxmtime = mtime unless mtime == 0
    end if data
  end

  def self.update_projpack(proj, backend, mypackages)
    packages = []
    mypackages.each do |key, package|
      if package.project == proj
        packages << package
      end
    end

    check_md5(proj, backend, packages, mypackages)
  end

  def self.update_projpack(proj, backend, mypackages)
    packages = []
    mypackages.each do |key, package|
      if package.project == proj
        packages << package
      end
    end
    
    check_md5(proj, backend, packages, mypackages)
  end

  def self.fetch_jobhistory(backend, proj, repo, arch, mypackages)
    # we do some fancy caching in here as the function called is pretty expensive and often called
    # first we check the last line of the job history (limit 1) and then we check if it changed
    # against the url we expect to query. As the url is too long to be used as meaningful hash we
    # generate the md5
    path = '/build/%s/%s/%s/_jobhistory' % [CGI.escape(proj), CGI.escape(repo), arch]
    begin
      currentlast=backend.direct_http( URI(path + '?limit=1') )
    rescue ActiveXML::Transport::NotFoundError
      # now ths is an ugly project, no backend data -> e.g. no repos
      return nil
    end

    uri = path + '?code=lastfailures'
    mypackages.each do |key, package|
      if package.project == proj
        uri += "&package=" + CGI.escape(package.name)
      end
    end

    key = Digest::MD5.hexdigest(uri)

    lastlast = Rails.cache.read(key + '_last')
    if currentlast != lastlast
      Rails.cache.delete key
    end

    Rails.cache.fetch(key) do
      Rails.cache.write(key + '_last', currentlast)
      d = backend.direct_http( URI(uri) , :timeout => 1000 )
      data = ActiveXML::Node.new(d) unless d.blank?
      return nil unless data
      ret = Hash.new
      reponame = repo + "/" + arch
      data.each('/jobhistlist/jobhist') do |p|
        packname = p.value('package')
        ret[packname] ||= BuildInfo.new
        code = p.value('code')
        readytime = begin Integer(p.value('readytime')) rescue 0 end
        if code == "unchanged" || code == "succeeded"
          ret[packname].success(reponame, readytime, p.value('srcmd5'))
        else
          ret[packname].failure(reponame, readytime, p.value('srcmd5'))
        end
        versrel = p.value('versrel').split('-')
        ret[packname].set_version(versrel[0..-2].join('-'), versrel[-1], readytime)
      end
      ret
    end
  end

  def self.update_jobhistory(targetproj, dbproj, backend, mypackages)
    dbproj.repositories_linking_project(targetproj, backend).each do |r|
      r.each_arch do |arch|
        infos = fetch_jobhistory(backend, dbproj.name, r.name, arch.text, mypackages)
        next if infos.nil?
        infos.each do |packname, bi|
          key = dbproj.name + "/" + packname
          next unless mypackages.has_key?(key)
          mypackages[key].add_buildinfo(bi)
        end
      end
    end
  end

  def self.add_recursively(mypackages, projects, dbpack)
    pack = PackInfo.new(dbpack)
    return if mypackages.has_key? pack.key

    if dbpack.develpackage
      pack.devel_project = dbpack.develpackage.project.name
      pack.devel_package = dbpack.develpackage.name
      projects[pack.devel_project] = dbpack.develpackage.project
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
    #return (name =~ /sy/)
    return true
  end

  def self.memory_usage
    number_to_human_size(`ps -o rss= -p #{Process.pid}`.to_i * 1024)
  end

  def self.calc_status(dbproj, backend)
    mypackages = Hash.new

    if ! dbproj
      puts "invalid project " + proj
      return mypackages
    end
    projects = Hash.new
    projects[dbproj.name] = dbproj
    dbproj.packages.each do |dbpack|
      next unless filter_by_package_name(dbpack.name)
      begin
        dbpack.resolve_devel_package
      rescue Package::CycleError
        next
      end
      add_recursively(mypackages, projects, dbpack)
    end

    projects.each do |name,proj|
      update_jobhistory(dbproj, proj, backend, mypackages)
      update_projpack(name, backend, mypackages)
    end

    dbproj.packages.each do |dbpack|
      next unless filter_by_package_name(dbpack.name)
      key = dbproj.name + "/" + dbpack.name
      move_devel_package(mypackages, key)
    end

    links = Hash.new
    # find links
    mypackages.values.each do |package|
      if package.project == dbproj.name and package.link.project
        links[package.link.project] ||= Array.new
        links[package.link.project] << package.link.package
      end
    end

    links.each do |proj, packages|
      tocheck = Array.new
      packages.each do |name|
        pack = Package.find_by_project_and_name(proj, name)
        next unless pack # broken link
        pack = PackInfo.new(pack)
        next if mypackages.has_key? pack.key
        tocheck << pack
        mypackages[pack.key] = pack
      end
      check_md5(proj, backend, tocheck, mypackages) unless tocheck.empty?
    end

    mypackages.values.each do |package|
      if package.project == dbproj.name and package.link.project
        newkey = package.link.project + "/" + package.link.package
	# broken links
	next unless mypackages.has_key? newkey
        package.link.targetmd5 = mypackages[newkey].verifymd5
        package.link.targetmd5 ||= mypackages[newkey].srcmd5
      end
    end

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
    values.sort! {|a,b| a[0] <=> b[0]}

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
