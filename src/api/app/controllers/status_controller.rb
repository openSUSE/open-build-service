require 'project_status_helper'

class StatusController < ApplicationController
  
  def messages
    # this displays the status messages the Admin can enter for users.
    if request.get?

      @messages = StatusMessage.find :all,
        :conditions => "ISNULL(deleted_at)",
        :limit => params[:limit],
        :order => 'status_messages.created_at DESC',
        :include => :user
      @count = StatusMessage.find( :first, :select => 'COUNT(*) AS cnt' ).cnt

    elsif request.put?

      # check permissions
      unless permissions.status_message_create
        render_error :status => 403, :errorcode => "permission denied",
          :message => "message(s) cannot be created, you have not sufficient permissions"
        return
      end

      new_messages = ActiveXML::XMLNode.new( request.raw_post )

      begin
        if new_messages.has_element? 'message'
          # message(s) are wrapped in outer xml tag 'status_messages'
          new_messages.each_message do |msg|
            message = StatusMessage.new
            message.message = msg.to_s
            message.severity = msg.value :severity
            message.user = @http_user
            message.save
          end
        else
          raise RuntimeError.new 'no message' if new_messages.element_name != 'message'
          # just one message, NOT wrapped in outer xml tag 'status_messages'
          message = StatusMessage.new
          message.message = new_messages.to_s
          message.severity = new_messages.value :severity
          message.user = @http_user
          message.save
        end
        render_ok
      rescue RuntimeError
        render_error :status => 400, :errorcode => "error creating message(s)",
          :message => "message(s) cannot be created"
        return
      end

    elsif request.delete?

      # check permissions
      unless permissions.status_message_create
        render_error :status => 403, :errorcode => "permission denied",
          :message => "message cannot be deleted, you have not sufficient permissions"
        return
      end

      begin
        StatusMessage.find( params[:id] ).delete
        render_ok
      rescue
        render_error :status => 400, :errorcode => "error deleting message",
          :message => "error deleting message - id not found or not given"
      end

    else

      render_error :status => 400, :errorcode => "only_put_or_get_method_allowed",
        :message => "only PUT or GET method allowed for this action"
      return

    end
  end

  def workerstatus
    begin
      data = Rails.cache.read('workerstatus')
    rescue Zlib::GzipFile::Error
      data = nil
    end
    data=ActiveXML::Base.new(data || update_workerstatus_cache)
    #accessprjs  = DbProject.find_by_sql("select p.id from db_projects p join flags f on f.db_project_id = p.id where f.flag='access'")
    #accesspkgs  = DbPackage.find_by_sql("select p.id from db_packages p join flags f on f.db_package_id = p.id where f.flag='access'")
    data.each_building do |b|
      prj = DbProject.find_by_name(b.project)
      # no prj -> we are not allowed
      if prj.nil?
        logger.debug "workerstatus2clean: hiding #{b.project} for user #{@http_user.login}"
        b.data.attributes['project'] = "---"
        b.data.attributes['repository'] = "---"
        b.data.attributes['package'] = "---"
     end
    end
    send_data data.dump_xml
  end

  def history
    required_parameters :hours, :key
    samples = begin Integer(params[:samples] || '100') rescue 0 end
    samples = [samples, 1].max

    hours = begin Integer(params[:hours] || '24') rescue 24 end
    logger.debug "#{Time.now.to_i} to #{hours.to_i}"
    starttime = Time.now.to_i - hours.to_i * 3600
    data = Array.new
    values = StatusHistory.find(:all, :conditions => [ "time >= ? AND \`key\` = ?", starttime, params[:key] ]).collect {|line| [line.time.to_i, line.value.to_f] }
    builder = FasterBuilder::XmlMarkup.new( :indent => 2 )
    xml = builder.history do
      StatusHelper.resample(values, samples).each do |time,val|
	builder.value( :time => time,
		      :value => val ) # for debug, :timestring => Time.at(time)  )
      end
    end
    render :text => xml.target!, :content_type => "text/xml"
  end

  def update_workerstatus_cache
    # do not add hiding in here - this is purely for statistics
    ret = backend_get('/build/_workerstatus')
    data=REXML::Document.new(ret)

    mytime = Time.now.to_i
    Rails.cache.write('workerstatus', ret)
    data.root.each_element('blocked') do |e|
      line = StatusHistory.new
      line.time = mytime
      line.key = 'blocked_%s' % [ e.attributes['arch'] ]
      line.value = e.attributes['jobs']
      line.save
    end
    data.root.each_element('waiting') do |e|
      line = StatusHistory.new
      line.time = mytime
      line.key = "waiting_#{e.attributes['arch']}"
      line.value = e.attributes['jobs']
      line.save
    end
    data.root.each_element('scheduler') do |s|
      queue = s.elements['queue']
      next unless queue
      arch = s.attributes['arch']
      StatusHistory.create :time => mytime, :key => "squeue_high_#{arch}", :value => queue.attributes['high']
      StatusHistory.create :time => mytime, :key => "squeue_next_#{arch}", :value => queue.attributes['next']
      StatusHistory.create :time => mytime, :key => "squeue_med_#{arch}",  :value => queue.attributes['med']
      StatusHistory.create :time => mytime, :key => "squeue_low_#{arch}",  :value => queue.attributes['low']
    end
    
    allworkers = Hash.new
    workers = Hash.new
    %w{building idle}.each do |state|
      data.root.each_element(state) do |e|
	id=e.attributes['workerid']
	if workers.has_key? id
	  logger.debug 'building+idle worker'
	  next
	end
	workers[id] = 1
	key = state + '_' + e.attributes['hostarch']
	allworkers["building_#{e.attributes['hostarch']}"] ||= 0
	allworkers["idle_#{e.attributes['hostarch']}"] ||= 0
	allworkers[key] = allworkers[key] + 1
      end
    end
    
    allworkers.each do |key,value|
      line = StatusHistory.new
      line.time = mytime
      line.key = key
      line.value = value
      line.save
    end
    
    ret
  end
  # not an action, but called from delayed job
  # private :update_workerstatus_cache

  def project
     dbproj = DbProject.get_by_name(params[:id])
     key='project_status_xml_%s' % dbproj.name
     xml = Rails.cache.fetch(key, :expires_in => 10.minutes) do
       @packages = dbproj.complex_status(backend)
       render_to_string 
     end
     render :text => xml
  end

  def bsrequest_repos_map(project)
    ret = Hash.new
    uri = URI( "/getprojpack?project=#{CGI.escape(project.to_s)}&nopackages&withrepos&expandedrepos" )
    xml = ActiveXML::Base.new( backend.direct_http( uri ) )
    xml.project.each_repository do |repo|
      repo.each_path do |path|
        ret[path.project.to_s] ||= Array.new
        ret[path.project.to_s] << repo
      end
    end

    return ret
  end
  private :bsrequest_repos_map

  def bsrequest_repo_list(project, repo, arch)
    ret = Hash.new
    data = Rails.cache.fetch(CGI.escape("repo_list_%s_%s_%s" % [project, repo, arch]), :expires_in => 5.minutes) do
      uri = URI( "/build/#{CGI.escape(project)}/#{CGI.escape(repo)}/#{CGI.escape(arch)}/_repository")
      backend.direct_http( uri )
    end

    repo = ActiveXML::Base.new( data )
    repo.each_binary do |b|
      name=b.value(:filename).sub('.rpm', '')
      ret[name] = 1
    end
    return ret
  end
  private :bsrequest_repo_list

  def bsrequest
    required_parameters :id
    req = BsRequest.find :id => params[:id]
    if req.action.value('type') != 'submit'
      render :text => "<status id='#{params[:id]}' code='unknown'>Not submit</status>\n" and return
    end

    begin
      sproj = DbProject.get_by_name(req.action.source.project)
      tproj = DbProject.get_by_name(req.action.target.project)
    rescue DbProject::UnknownObjectError => e
      render :text => "<status id='#{params[:id]}' code='error'>Can't find project #{e.message}k</status>\n" and return
    end

    tocheck_repos = Array.new

    targets = bsrequest_repos_map(tproj.name)
    sources = bsrequest_repos_map(sproj.name)
    sources.each do |key, value|
      if targets.has_key?(key): 
          tocheck_repos << sources[key]
      end
    end

    tocheck_repos.flatten!
    tocheck_repos.uniq!

    if tocheck_repos.empty?
      render :text => "<status id='#{params[:id]}' code='warning'>No repositories build against target</status>\n"
      return
    end
    begin
      dir = Directory.find(:project => req.action.source.project,
			   :package => req.action.source.package,
			   :expand => 1, :rev => req.action.source.value('rev'))
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      render :text => "<status id='#{params[:id]}' code='error'>Can't list sources: #{message}</status>\n"
      return
    end

    # check current srcmd5
    begin
      cdir = Directory.find(:project => req.action.source.project,
                           :package => req.action.source.package,
                           :expand => 1)
      csrcmd5 = cdir.value('srcmd5')
    rescue ActiveXML::Transport::Error => e
      csrcmd5 = nil
    end

    unless dir
      render :text => '<status code="error">Source package does not exist</status>\n' and return
    end
    srcmd5 = dir.value('srcmd5')

    outputxml = "<status id='#{params[:id]}'>\n"
    
    re_filename = Regexp.new('^(.*)-[^-]*-[^-]*\.([^-.]*).rpm')
    tocheck_repos.each do |srep|
      outputxml << " <repository name='#{srep.name}'>\n"
      trepo = []
      archs = []
      srep.each_path do |p|
	if p.project != sproj.name
	  r = Repository.find_by_project_and_repo_name(p.project, p.value(:repository))
          if r.db_project = tproj
            r.architectures.each {|a| archs << a.name }
          end
          trepo << [p.project, p.value(:repository)]
	end
      end
      archs.uniq!
      if trepo.empty?
	render :text => "<status id='#{params[:id]}' code='warning'>Can not find repository building against target</status>\n" and return
      end
      logger.debug trepo.inspect
      archs.each do |arch|
        everbuilt = 0
        eversucceeded = 0
	buildcode=nil
	hist = Jobhistory.find(:project => sproj.name, 
			       :repository => srep.name, 
			       :package => req.action.source.package,
			       :arch => arch.to_s, :limit => 20 )
	next unless hist
	hist.each_jobhist do |jh|
	  next if jh.srcmd5 != srcmd5
	  everbuilt = 1
	  if jh.code == 'succeeded'
	    buildcode='succeeded'
	    eversucceeded = 1
	    break
	  end
	end
	missingdeps=[]
	if eversucceeded
	  uri = URI( "/build/#{CGI.escape(sproj.name)}/#{CGI.escape(srep.name)}/#{CGI.escape(arch.to_s)}/#{CGI.escape(req.action.source.package.to_s)}/_buildinfo")
	  buildinfo = ActiveXML::Base.new( backend.direct_http( uri ) )
	  packages = Hash.new
	  trepo.each do |p, r|
	    packages.merge!(bsrequest_repo_list(p, r, arch.to_s))
	  end

	  buildinfo.each_bdep do |b|
	    unless b.value(:preinstall)
	      unless packages.has_key? b.value(:name)
		missingdeps << b.name
	      end
	    end
	  end
          
          uri = URI( "/build/#{CGI.escape(sproj.name)}/#{CGI.escape(srep.name)}/#{CGI.escape(arch.to_s)}/#{CGI.escape(req.action.source.package.to_s)}")
          binaries = ActiveXML::Base.new( backend.direct_http( uri ) ) 
          binaries.each_binary do |f|
            # match to the repository filename
            m = re_filename.match(f.value(:filename)) 
            uri = URI( "/build/#{CGI.escape(sproj.name)}/#{CGI.escape(srep.name)}/#{m[2]}/_repository/#{m[1]}.rpm?view=fileinfo_ext")
            begin
              fileinfo = ActiveXML::Base.new( backend.direct_http( uri ) )
              fileinfo.each_requires_ext do |r|
                unless r.has_element? :providedby
                  missingdeps << "#{m[1]}:#{r.dep}"
                end
              end
            rescue ActiveXML::Transport::NotFoundError
	      # we ignore those we don't find atm
              logger.debug "can't find #{uri.to_s}"
            end
          end
	end
	# if the package does not appear in build history, check flags
	if everbuilt == 0
	  spkg = DbPackage.find_by_project_and_name req.action.source.project, req.action.source.package
	  pkg_flags = spkg.type_flags("build")
          buildflag=spkg.db_project.flag_status(nil, FlagHelper.default_for("build"), srep.name, 
						arch.to_s, sproj.type_flags("build"), pkg_flags)
	  if buildflag == 'disable'
	    buildcode='disabled'
	  end
        end

        if !buildcode && srcmd5 != csrcmd5 && everbuilt == 1:
          buildcode='failed' # has to be
        end
 
        unless buildcode
          buildcode='unknown'
          begin
            uri = URI( "/build/#{CGI.escape(sproj.name)}/_result?package=#{CGI.escape(req.action.source.package.to_s)}&repository=#{CGI.escape(srep.name)}&arch=#{CGI.escape(arch.to_s)}" )
            resultlist = ActiveXML::Base.new( backend.direct_http( uri ) )
            currentcode = resultlist.result.status.value(:code)
          rescue ActiveXML::Transport::Error
            currentcode = nil
          end
          if ['unresolvable', 'failed', 'broken'].include?(currentcode)
            buildcode='failed'
          end
          if ['building', 'scheduled', 'finished', 'signing', 'blocked'].include?(currentcode)
            buildcode='building'
          end
          if currentcode == 'excluded'
            buildcode='excluded'
          end
          # if it's currently succeeded but !everbuilt, it's different sources
          if currentcode == 'succeeded'
            if srcmd5 == csrcmd5
              buildcode='building' # guesssing
            else
              buildcode='outdated'
            end
          end
        end
	outputxml << "  <arch arch='#{arch.to_s}' result='#{buildcode}'"
	outputxml << " missing='#{missingdeps.join(',')}'" if missingdeps.size > 0
	outputxml << "/>\n"
      end
      outputxml << " </repository>\n"
    end
    outputxml << "</status>\n"

    if outputxml.blank?
      render :text => tocheck_repos.to_xml
    else
      render :text => outputxml
    end
  end

end
