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
     unless data
       data = update_workerstatus_cache 
       Rails.cache.write('workerstatus', data)
     end
     send_data data
  end

  def history
    required_parameters :hours, :key
    samples = begin Integer(params[:samples] || '100') rescue 0 end
    samples = [samples, 1].max

    hours = begin Integer(params[:hours] || '24') rescue 24 end
    logger.debug "#{Time.now.to_i} to #{hours.to_i}"
    starttime = Time.now.to_i - hours.to_i * 3600
    data = Array.new
    values = StatusHistory.find(:all, :conditions => [ "time >= ? AND `key` = ?", starttime, params[:key] ]).collect {|line| [line.time.to_i, line.value.to_f] }
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
    ret = backend_get('/build/_workerstatus')

    data=REXML::Document.new(ret)
    # FIXME2.2: THIS WON'T WORK AS IT'S READ FROM CACHE ANYWAY
    accessprjs  = DbProject.find_by_sql("select p.id from db_projects p join flags f on f.db_project_id = p.id where f.flag='access'")
    accesspkgs  = DbPackage.find_by_sql("select p.id from db_packages p join flags f on f.db_package_id = p.id where f.flag='access'")
    data.root.each_element('building') do |b|
      prj = DbProject.find_by_name(b.attributes['project'])
      pkg = prj.find_package(b.attributes['package']) if prj
      b.remove if (prj and accessprjs and accessprjs.include?(prj) and not @http_user.can_access?(prj)) or (pkg and accesspkgs and accesspkgs.include?(pkg) and not @http_user.can_access?(pkg))
    end
    ret=data.to_s

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

  def bsrequest
    required_parameters :id
    req = BsRequest.find :id => params[:id]
    if req.action.value('type') != 'submit'
      render :text => '<status code="unknown">Not submit</status>' and return
    end

    sproj = DbProject.get_by_name(req.action.source.project)
    tproj = DbProject.get_by_name(req.action.target.project)

    tocheck_repos = Array.new

    targets = bsrequest_repos_map(tproj.name)
    logger.debug targets.inspect
    sources = bsrequest_repos_map(sproj.name)
    logger.debug sources.inspect
    sources.each do |key, value|
      if targets.has_key?(key): 
          tocheck_repos << sources[key]
      end
    end

    tocheck_repos.flatten!

    if tocheck_repos.empty?
      render :text => '<status code="warning">No repositories build against target</status>'
      return
    end
    dir = Directory.find(:project => req.action.source.project,
			 :package => req.action.source.package,
			 :expand => 1, :rev => req.action.source.value('rev'))
    unless dir
      render :text => '<status code="error">Source package does not exist</status>' and return
    end
    srcmd5 = dir.value('srcmd5')

    logger.debug tocheck_repos.inspect

    outputxml = ''
    tocheck_repos.each do |srep|
      srep.each_arch do |arch|
        everbuilt = 0
        eversucceeded = 0
	hist = Jobhistory.find(:project => sproj.name, 
			       :repository => srep.name, 
			       :package => req.action.source.package,
			       :arch => arch.to_s, :limit => 20 )
	next unless hist
	hist.each_jobhist do |jh|
	  next if jh.srcmd5 != srcmd5
	  everbuilt = 1
	  if jh.code == 'succeeded'
	    eversucceeded = 1
	  end
	end
        outputxml = outputxml + "<status id='#{params[:id]}' code='what'>built=#{everbuilt} success=#{eversucceeded} repo=#{srep.name} arch=#{arch.to_s}</status>\n"
      end
    end

    if outputxml.blank?
      render :text => tocheck_repos.to_xml
    else
      render :text => outputxml
    end
  end

end
