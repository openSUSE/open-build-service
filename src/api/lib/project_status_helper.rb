require 'xml'

class PackInfo
	attr_accessor :version, :release
	attr_accessor :devel_project, :devel_package
	attr_accessor :srcmd5, :error
	attr_reader :name

	def initialize(name)
		@name = name
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
               :name => name,
               :version => version,
               :srcmd5 => srcmd5,
               :release => release) do
                 self.fails.each do |repo,time|
                   xml.failure(:repo => repo, :time => time)
                 end
                 if devel_project || devel_package
                   xml.develpack(:proj => devel_project, :pack => devel_package)
                 end
		 if @error then xml.error(error) end
		 @links.each do |proj,pack|
		    xml.link(:project => proj, :package => pack)
		 end
	     end
        end
end

class ProjectStatusHelper

  def self.calc_status(dbproj, backend)
     mypackages = Hash.new

     if ! dbproj
	puts "invalid project " + proj
	return mypackages
     end
     dbproj.db_packages.each do |dbpack|
	  name = dbpack.name
          pack = PackInfo.new(name)
          
          if dbpack.develpackage
	       pack.devel_project = dbpack.develpackage.db_project.name
	       pack.devel_package = dbpack.develpackage.name
          end
          mypackages[name] = pack
     end
     dbproj.repositories.each do |r|
        r.architectures.each do |arch|
           reponame = r.name + "/" + arch.name
           puts 'get "build/%s/%s/%s/_jobhistory?code=lastfailures"' % [dbproj.name, r.name, arch.name]
           d = backend.direct_http( URI('/build/%s/%s/%s/_jobhistory?code=lastfailures' % [dbproj.name, r.name, arch.name]) , :timeout => 1000 )
           data = XML::Parser.string(d).parse
           if data then 
              data.find('/jobhistlist/jobhist').each do |p|
		packname = p.attributes['package']
                next unless mypackages.has_key?(packname)
		code = p.attributes['code']
		if code == "unchanged" || code == "succeeded"
			mypackages[packname].success(reponame, Integer(p.attributes['readytime']))
		else
			mypackages[packname].failure(reponame, Integer(p.attributes['readytime']))
		end
		versrel=p.attributes['versrel'].split('-')
		mypackages[packname].version = versrel[0..-2].join('-')
		mypackages[packname].release = versrel[-1]
             end
           end
        end
     end 
     #d = File.read('getprojpack.xml')
     puts 'get /getprojpack?project=%s&withsrcmd5=1&ignoredisable=1' % dbproj.name
     d = backend.direct_http( URI('/getprojpack?project=%s&withsrcmd5=1&ignoredisable=1' % dbproj.name) )
     data = XML::Parser.string(d).parse
     if data then data.find('/projpack/project/package').each do |p|
        packname = p.attributes['name']
        next unless mypackages.has_key?(packname)
        if p.attributes['verifymd5']
	    mypackages[packname].srcmd5 = p.attributes['verifymd5']
        else
	    mypackages[packname].srcmd5 = p.attributes['srcmd5']
        end
        p.find('linked').each do |l|
		mypackages[packname].linked(l.attributes['project'], l.attributes['package'])
        end
	p.find('error').each do |e|
		mypackages[packname].error = e.text
	end
       end
     end
     return mypackages
  end
end
 
