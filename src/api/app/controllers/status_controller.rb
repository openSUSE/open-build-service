require 'status_helper'

class StatusController < ApplicationController

  def messages
    # this displays the status messages the Admin can enter for users.
    if request.get?

      if params[:id]
        @messages = [StatusMessage.find(params[:id])]
        @count    = 1
      else
        @messages = StatusMessage.alive.limit(params[:limit]).order("created_at DESC").includes(:user)
        @count    = @messages.size
      end

    elsif request.put?

      # check permissions
      unless permissions.status_message_create
        render_error :status  => 403, :errorcode => "permission denied",
                     :message => "message(s) cannot be created, you have not sufficient permissions"
        return
      end

      new_messages = ActiveXML::Node.new(request.raw_post)

      begin
        if new_messages.has_element? 'message'
          # message(s) are wrapped in outer xml tag 'status_messages'
          new_messages.each_message do |msg|
            message          = StatusMessage.new
            message.message  = msg.to_s
            message.severity = msg.value :severity
            message.user     = @http_user
            message.save
          end
        else
          raise RuntimeError.new 'no message' if new_messages.element_name != 'message'
          # just one message, NOT wrapped in outer xml tag 'status_messages'
          message          = StatusMessage.new
          message.message  = new_messages.to_s
          message.severity = new_messages.value :severity
          message.user     = @http_user
          message.save
        end
        render_ok
      rescue RuntimeError
        render_error :status  => 400, :errorcode => "error creating message(s)",
                     :message => "message(s) cannot be created"
        return
      end

    elsif request.delete?

      # check permissions
      unless permissions.status_message_create
        render_error :status  => 403, :errorcode => "permission denied",
                     :message => "message cannot be deleted, you have not sufficient permissions"
        return
      end

      begin
        StatusMessage.find(params[:id]).delete
        render_ok
      rescue
        render_error :status  => 400, :errorcode => "error deleting message",
                     :message => "error deleting message - id not found or not given"
      end

    end
  end

  def workerstatus
    begin
      data = Rails.cache.read('workerstatus')
    rescue Zlib::GzipFile::Error
      data = nil
    end
    data=ActiveXML::Node.new(data || update_workerstatus_cache)
    data.each_building do |b|
      prj = Project.find_by_name(b.project)
      # no prj -> we are not allowed
      if prj.nil?
        logger.debug "workerstatus2clean: hiding #{b.project} for user #{@http_user.login}"
        b.set_attribute('project', "---")
        b.set_attribute('repository', "---")
        b.set_attribute('package', "---")
      end
    end
    # FIXME2.5: The current architecture model is a gross hack, not connected at all 
    #           to the backend config.
    data.each_partition do |partition|
      partition.each_daemon do |daemon|
        next unless daemon.type == "scheduler"
        if a=Architecture.find_by_name(daemon.arch)
          a.available=true
        end
      end
    end
    send_data data.dump_xml
  end

  def history
    required_parameters :hours, :key
    samples = begin
      Integer(params[:samples] || '100') rescue 0
    end
    samples = [samples, 1].max

    hours = begin
      Integer(params[:hours] || '24') rescue 24
    end
    logger.debug "#{Time.now.to_i} to #{hours.to_i}"
    starttime = Time.now.to_i - hours.to_i * 3600
    values    = StatusHistory.where("time >= ? AND \`key\` = ?", starttime, params[:key]).pluck(:time, :value).collect { |time,value| [time.to_i, value.to_f] }
    builder   = Builder::XmlMarkup.new(:indent => 2)
    xml       = builder.history do
      StatusHelper.resample(values, samples).each do |time, val|
        builder.value(:time  => time,
                      :value => val) # for debug, :timestring => Time.at(time)  )
      end
    end
    render :text => xml, :content_type => "text/xml"
  end

  def update_workerstatus_cache
    # do not add hiding in here - this is purely for statistics
    ret = backend_get('/build/_workerstatus')
    data=REXML::Document.new(ret)

    mytime = Time.now.to_i
    Rails.cache.write('workerstatus', ret, :expires_in => 3.minutes)
    data.root.each_element('blocked') do |e|
      line       = StatusHistory.new
      line.time  = mytime
      line.key   = 'blocked_%s' % [e.attributes['arch']]
      line.value = e.attributes['jobs']
      line.save
    end
    data.root.each_element('waiting') do |e|
      line       = StatusHistory.new
      line.time  = mytime
      line.key   = "waiting_#{e.attributes['arch']}"
      line.value = e.attributes['jobs']
      line.save
    end
    data.root.each_element('partition') do |d|
      d.each_element('daemon') do |daemon|
        next unless daemon.attributes['type'] == 'scheduler'
        queue = daemon.elements['queue']
        next unless queue
        arch = daemon.attributes['arch']
        StatusHistory.create :time => mytime, :key => "squeue_high_#{arch}", :value => queue.attributes['high']
        StatusHistory.create :time => mytime, :key => "squeue_next_#{arch}", :value => queue.attributes['next']
        StatusHistory.create :time => mytime, :key => "squeue_med_#{arch}", :value => queue.attributes['med']
        StatusHistory.create :time => mytime, :key => "squeue_low_#{arch}", :value => queue.attributes['low']
      end
    end

    allworkers = Hash.new
    workers    = Hash.new
    %w{building idle}.each do |state|
      data.root.each_element(state) do |e|
        id=e.attributes['workerid']
        if workers.has_key? id
          logger.debug 'building+idle worker'
          next
        end
        workers[id]                                        = 1
        key                                                = state + '_' + e.attributes['hostarch']
        allworkers["building_#{e.attributes['hostarch']}"] ||= 0
        allworkers["idle_#{e.attributes['hostarch']}"]     ||= 0
        allworkers[key]                                    = allworkers[key] + 1
      end
    end

    allworkers.each do |key, value|
      line       = StatusHistory.new
      line.time  = mytime
      line.key   = key
      line.value = value
      line.save
    end

    ret
  end

  # not an action, but called from delayed job
  # private :update_workerstatus_cache

  def project
    dbproj = Project.get_by_name(params[:project])
    key    ='project_status_xml_%s' % dbproj.name
    xml    = Rails.cache.fetch(key, :expires_in => 10.minutes) do
      @packages = dbproj.complex_status(backend)
      render_to_string
    end
    render :text => xml
  end



  def bsrequest
    required_parameters :id
    Suse::Backend.start_test_backend if Rails.env.test?

    outputxml = "<status id='#{params[:id]}'>\n"

    BsRequestAction.where(bs_request_id: params[:id]).each do |action|

      if action.action_type != :submit
        render :text => "<status id='#{params[:id]}' code='unknown'>Not submit</status>\n" and return
      end

      sproj = Project.find_by_name!(action.source_project)
      tproj = Project.find_by_name!(action.target_project)
      spkg = sproj.packages.find_by_name!(action.source_package)

      begin
        dir = Directory.find(:project => action.source_project,
                             :package => action.source_package,
                             :expand  => 1, :rev => action.source_rev)
      rescue ActiveXML::Transport::Error => e
        render :text => "<status id='#{params[:id]}' code='error'>Can't list sources: #{e.summary}</status>\n"
        return
      end
      unless dir
        render :text => '<status code="error">Source package does not exist</status>\n' and return
      end
      srcmd5 = dir.value('srcmd5')
      result = spkg.buildstatus(target_project: tproj, srcmd5: srcmd5)
      result.each do |repo, status|
        outputxml << " <repository name='#{repo}'>\n"
        status.each do |arch, archstat|
          outputxml << "  <arch arch='#{arch}' result='#{archstat[:result]}'"
          outputxml << " missing='#{archstat[:missing]}'" if archstat[:missing]
          outputxml << "/> \n"
        end
        outputxml << " </repository>\n"

      end
    end

    outputxml << "</status>\n"

    if outputxml.blank?
      render :text => tocheck_repos.to_xml
    else
      render :text => outputxml
    end
  end

end
