require 'xml'

class PackInfo
	attr_accessor :version, :release
	attr_accessor :devel_project, :devel_package
	attr_accessor :srcmd5, :error
	attr_reader :name, :project
  attr_reader :key
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
		@links = Array.new
	end

	def success(reponame, time)
		# try to remember last success
		unless @last_success.has_key? reponame
			@last_success[reponame] = time
		else
			oldtime = @last_success[reponame]
			if oldtime > time
				time = oldtime
			end
			@last_success[reponame] = time
		end
	end

	def failure(reponame, time)
		# we only track the first failure returned
		return if @failed.has_key? reponame
		@failed[reponame] = time
	end

	def fails
		ret = Hash.new
		@failed.each do |repo,time|
			ls = @last_success[repo] || 0
			if ls < time
				ret[repo] = time
			end
		end
		return ret
	end

	def linked(proj, pack)
		@links << [proj, pack]
	end

	def to_xml(options = {}) 
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.package(
      :project => project,
      :name => name,
      :version => version,
      :srcmd5 => srcmd5,
      :release => release) do
      self.fails.each do |repo,time|
        xml.failure(:repo => repo, :time => time)
      end
      if develpack
        xml.develpack(:proj => devel_project, :pack => devel_package) do
		      develpack.to_xml(:builder => xml)
        end
      end
      if @error then xml.error(error) end
      @links.each do |proj,pack|
		    xml.link(:project => proj, :package => pack)
      end
    end
  end
end

class ProjectStatusHelper

  def self.update_projpack(proj, backend, mypackages)
    puts 'get /getprojpack?project=%s&withsrcmd5=1&ignoredisable=1' % proj
    d = backend.direct_http( URI('/getprojpack?project=%s&withsrcmd5=1&ignoredisable=1' % proj), :timeout => 1000 )
    data = XML::Parser.string(d).parse
    if data then data.find('/projpack/project/package').each do |p|
        packname = p.attributes['name']
        key = proj + "/" + packname
        next unless mypackages.has_key?(key)
        if p.attributes['verifymd5']
          mypackages[key].srcmd5 = p.attributes['verifymd5']
        else
          mypackages[key].srcmd5 = p.attributes['srcmd5']
        end
        p.find('linked').each do |l|
          mypackages[key].linked(l.attributes['project'], l.attributes['package'])
        end
        p.find('error').each do |e|
          mypackages[key].error = e.content
        end
      end
    end
  end

  def self.update_jobhistory(dbproj, backend, mypackages)
    dbproj.repositories.each do |r|
      r.architectures.each do |arch|
        reponame = r.name + "/" + arch.name
        puts 'get "build/%s/%s/%s/_jobhistory?code=lastfailures"' % [dbproj.name, r.name, arch.name]
        d = backend.direct_http( URI('/build/%s/%s/%s/_jobhistory?code=lastfailures' % [dbproj.name, r.name, arch.name]) , :timeout => 1000 )
        data = XML::Parser.string(d).parse
        if data then
          data.find('/jobhistlist/jobhist').each do |p|
            packname = p.attributes['package']
            key = dbproj.name + "/" + packname
            next unless mypackages.has_key?(key)
            code = p.attributes['code']
            if code == "unchanged" || code == "succeeded"
              mypackages[key].success(reponame, Integer(p.attributes['readytime']))
            else
              mypackages[key].failure(reponame, Integer(p.attributes['readytime']))
            end
            versrel=p.attributes['versrel'].split('-')
            mypackages[key].version = versrel[0..-2].join('-')
            mypackages[key].release = versrel[-1]
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
    develpack = mypackages.delete newkey
    pack.develpack = develpack
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
      #next unless dbpack.name =~ /^perl-Tk.*/
      dbpack.resolve_devel_package
      add_recursively(mypackages, projects, dbpack)
    end

    projects.each do |name,proj|
      update_jobhistory(proj, backend, mypackages)
      update_projpack(name, backend, mypackages)
    end

    dbproj.db_packages.each do |dbpack|
      key = dbproj.name + "/" + dbpack.name
      move_devel_package(mypackages, key)
    end
    
    return mypackages
  end
end
 
