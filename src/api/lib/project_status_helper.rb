
class PackInfo
	attr_accessor :version, :release
	attr_accessor :devel_project, :devel_package
	attr_reader :name

	def initialize(name)
		@name = name
		@failed = Hash.new
		@last_success = Hash.new
		@devel_proj = nil
		@devel_pack = nil
		@version = nil
		@release = nil
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
end

class ProjectStatusHelper

  def self.calc_status(dbproj)
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
     backend = ActiveXML::Config.transport_for :packstatus
     dbproj.repositories.each do |r|
        r.architectures.each do |arch|
           puts 'get "build/%s/%s/%s/_jobhistory?code=lastfailures"' % [dbproj.name, r.name, arch.name]
           d = backend.direct_http( URI('/build/%s/%s/%s/_jobhistory?code=lastfailures' % [dbproj.name, r.name, arch.name]) )
           data = REXML::Document.new(d)
           data.root.each_element('jobhist') do |p|
		packname = p.attribute('package').value
                next unless mypackages.has_key?(packname)
		reponame = r.name + "/" + arch.name
		code = p.attribute('code').value
		if code == "unchanged" || code == "succeeded"
			mypackages[packname].success(reponame, Integer(p.attribute('readytime').value))
		else
			mypackages[packname].failure(reponame, Integer(p.attribute('readytime').value))
		end
		versrel=p.attribute('versrel').value.split('-')
		mypackages[packname].version = versrel[0..-2].join('-')
		mypackages[packname].release = versrel[-1]
           end
        end
     end 
     mypackages
  end
end
 
