require 'xml'
require 'ostruct'
require 'digest/md5'

class LinkInfo
  attr_accessor :project
  attr_accessor :package
  attr_accessor :targetmd5
end

class PackInfo
  attr_reader :version, :release
  attr_accessor :devel_project, :devel_package
  attr_accessor :srcmd5, :verifymd5, :error, :link
  attr_reader :name, :project, :key
  attr_accessor :develpack

  def initialize(projname, name)
    @project = projname
    @name = name
    @key = projname + "/" + name
    @failed = Hash.new
    @last_success = Hash.new
    @devel_project = nil
    @devel_package = nil
    @version = nil
    @release = nil
    # we avoid going back in versions by avoiding going back in time
    # the last built version wins (repos may have different versions)
    @versiontime = nil
    @link = LinkInfo.new
  end

  def set_version(version, release, time)
    return if @versiontime and @versiontime > time
    @versiontime = time
    @version = version
    @release = release
  end

  def success(reponame, time, md5)
    # try to remember last success
    if @last_success.has_key? reponame
      return if @last_success[reponame][0] > time
    end
    @last_success[reponame] = OpenStruct.new :time => time, :md5 => md5
  end

  def failure(reponame, time, md5)
    # we only track the first failure time but latest md5 returned
    if @failed.has_key? reponame
      time = @failed[reponame].time
    end
    @failed[reponame] = OpenStruct.new :time => time, :md5 => md5
  end

  def fails
    ret = Hash.new
    @failed.each do |repo,tuple|
      ls = begin @last_success[repo].time rescue 0 end
      if ls < tuple.time
        ret[repo] = tuple
      end
    end
    return ret
  end

  def to_xml(options = {}) 
    # return packages not having sources
    return if srcmd5.blank?
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    opts = { :project => project,
             :name => name,
             :version => version,
             :srcmd5 => srcmd5,
             :release => release }
    unless verifymd5.blank? or verifymd5 == srcmd5
      opts[:verifymd5] = verifymd5
    end
    xml.package(opts) do
      self.fails.each do |repo,tuple|
        xml.failure(:repo => repo, :time => tuple.time, :srcmd5 => tuple.md5 )
      end
      if develpack
        xml.develpack(:proj => devel_project, :pack => devel_package) do
          develpack.to_xml(:builder => xml)
        end
      end
      if @error then xml.error(error) end
      if @link.project
        xml.link(:project => @link.project, :package => @link.package, :targetmd5 => @link.targetmd5)
      end
    end
  end
end

class ProjectStatusHelper

  def self.get_xml(backend, uri)
    key = Digest::MD5.hexdigest(uri)
    d = Rails.cache.fetch(key, :expires_in => 2.hours) do
      backend.direct_http( URI(uri), :timeout => 1000 )
    end
    XML::Parser.string(d).parse
  end

  def self.check_md5(proj, backend, packages, mypackages)
    uri = '/getprojpack?project=%s&withsrcmd5=1&ignoredisabled=1' % CGI.escape(proj)
    packages.each do |package|
      uri += "&package=" + CGI.escape(package.name)
    end
    data = get_xml(backend, uri)
    data.find('/projpack/project/package').each do |p|
      packname = p.attributes['name']
      key = proj + "/" + packname
      next unless mypackages.has_key?(key)
      mypackages[key].srcmd5 = p.attributes['srcmd5']
    end if data
  end

  def self.update_projpack(proj, backend, mypackages)
    uri = '/getprojpack?project=%s&withsrcmd5=1&ignoredisabled=1' % CGI.escape(proj)
    mypackages.each do |key, package|
      if package.project == proj
	uri += "&package=" + CGI.escape(package.name)
      end
    end

    data = get_xml(backend, uri)
    data.find('/projpack/project/package').each do |p|
      packname = p.attributes['name']
      key = proj + "/" + packname
      next unless mypackages.has_key?(key)
      if p.attributes['verifymd5']
	mypackages[key].verifymd5 = p.attributes['verifymd5']
      end
      mypackages[key].srcmd5 = p.attributes['srcmd5']
      p.find('linked').each do |l|
	mypackages[key].link.project = l.attributes['project']
	mypackages[key].link.package = l.attributes['package']
      end
      p.find('error').each do |e|
	mypackages[key].error = e.content
      end
    end if data
  end

  def self.fetch_jobhistory(backend, proj, repo, arch, mypackages)
    # we do some fancy caching in here as the function called is pretty expensive and often called
    # first we check the last line of the job history (limit 1) and then we check if it changed
    # against the url we expect to query. As the url is too long to be used as meaningful hash we
    # generate the md5
    path = '/build/%s/%s/%s/_jobhistory' % [CGI.escape(proj), CGI.escape(repo), arch]
    currentlast=backend.direct_http( URI(path + '?limit=1') )

    uri = path + '?code=lastfailures'
    mypackages.each do |key, package|
      if package.project == proj
	uri += "&package=" + CGI.escape(package.name)
      end
    end

    key = Digest::MD5.hexdigest(uri)

    lastlast = Rails.cache.read(key + '_last', :raw => true)
    if currentlast != lastlast 
      Rails.cache.delete key
    end
   
    Rails.cache.fetch(key, :raw => true) do
      Rails.cache.write(key + '_last', currentlast, :raw => true)
      backend.direct_http( URI(uri) , :timeout => 1000 )
    end
  end

  def self.update_jobhistory(dbproj, backend, mypackages)
    dbproj.repositories.each do |r|
      r.architectures.each do |arch|
        reponame = r.name + "/" + arch.name
        d = fetch_jobhistory(backend, dbproj.name, r.name, arch.name, mypackages)
        data = XML::Parser.string(d).parse
        if data then
          data.find('/jobhistlist/jobhist').each do |p|
            packname = p.attributes['package']
            key = dbproj.name + "/" + packname
            next unless mypackages.has_key?(key)
            code = p.attributes['code']
            readytime = begin Integer(p['readytime']) rescue 0 end
            if code == "unchanged" || code == "succeeded"
              mypackages[key].success(reponame, readytime, p['srcmd5'])
            else
              mypackages[key].failure(reponame, readytime, p['srcmd5'])
            end
            versrel=p.attributes['versrel'].split('-')
            mypackages[key].set_version(versrel[0..-2].join('-'), versrel[-1], readytime)
          end
        end
      end
    end 
  end

  def self.add_recursively(mypackages, projects, dbpack)
    name = dbpack.name
    pack = PackInfo.new(dbpack.db_project.name, name)
    return if mypackages.has_key? pack.key

    if dbpack.develpackage
      pack.devel_project = dbpack.develpackage.db_project.name
      pack.devel_package = dbpack.develpackage.name
      projects[pack.devel_project] = dbpack.develpackage.db_project
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
    #return (name =~ /Botan/)
    return true
  end

  def self.calc_status(dbproj, backend)
    mypackages = Hash.new

    if ! dbproj
      puts "invalid project " + proj
      return mypackages
    end
    projects = Hash.new
    projects[dbproj.name] = dbproj
    dbproj.db_packages.each do |dbpack|
      next unless filter_by_package_name(dbpack.name)
      begin
        dbpack.resolve_devel_package
      rescue DbPackage::CycleError => e
        next
      end
      add_recursively(mypackages, projects, dbpack)
    end

    projects.each do |name,proj|
      update_jobhistory(proj, backend, mypackages)
      update_projpack(name, backend, mypackages)
    end

    dbproj.db_packages.each do |dbpack|
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
	pack = PackInfo.new(proj, name)
	next if mypackages.has_key? pack.key
	tocheck << pack
	mypackages[pack.key] = pack
      end
      check_md5(proj, backend, tocheck, mypackages)
    end
    
    mypackages.values.each do |package|
      if package.project == dbproj.name and package.link.project
	newkey = package.link.project + "/" + package.link.package
	package.link.targetmd5 = mypackages[newkey].srcmd5
      end
    end

    # cleanup
    mypackages.keys.each do |key|
      mypackages.delete(key) if mypackages[key].project != dbproj.name
    end
    
    return mypackages
  end

  def self.logger
    RAILS_DEFAULT_LOGGER
  end
  
end

