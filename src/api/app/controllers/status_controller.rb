require_dependency 'status_helper'

class StatusController < ApplicationController

  class PermissionDeniedError < APIException
    setup 403
  end

  def list_messages
    @messages = StatusMessage.alive.limit(params[:limit]).order("created_at DESC").includes(:user)
    @count = @messages.size
    render xml: render_to_string(partial: "messages")
  end

  def show_message
    @messages = [StatusMessage.find(params[:id])]
    @count = 1
    render xml: render_to_string(partial: "messages")
  end

  class CreatingMessagesError < APIException
  end

  def update_messages
    # check permissions
    unless permissions.status_message_create
      raise PermissionDeniedError.new 'message(s) cannot be created, you have not sufficient permissions'
    end

    new_messages = ActiveXML::Node.new(request.raw_post)

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
      raise CreatingMessagesError.new "message(s) cannot be created"
    end
  end

  def delete_message
    # check permissions
    unless permissions.status_message_create
      raise PermissionDeniedError.new "message cannot be deleted, you have not sufficient permissions"
    end

    StatusMessage.find(params[:id]).delete
    render_ok
  end

  def workerstatus
    begin
      data = Rails.cache.read('workerstatus')
    rescue Zlib::GzipFile::Error
      data = nil
    end
    data=ActiveXML::Node.new(data || update_workerstatus_cache)
    prjs=Hash.new
    data.each_building do |b|
      prjs[b.project] = 1
    end
    names = Hash.new
    # now try to find those we have a match for (the rest are hidden from you
    Project.where(name: prjs.keys).pluck(:name).each do |n|
      names[n] = 1
    end
    data.each_building do |b|
      # no prj -> we are not allowed
      unless names.has_key? b.project
        logger.debug "workerstatus2clean: hiding #{b.project} for user #{User.current.login}"
        b.set_attribute('project', '---')
        b.set_attribute('repository', '---')
        b.set_attribute('package', '---')
      end
    end
    send_data data.dump_xml
  end

  def history
    required_parameters :hours, :key
    samples = begin
      Integer(params[:samples] || '100') rescue 0
    end
    @samples = [samples, 1].max

    hours = begin
      Integer(params[:hours] || '24') rescue 24
    end
    starttime = Time.now.to_i - hours.to_i * 3600
    @values = StatusHistory.where("time >= ? AND \`key\` = ?", starttime, params[:key]).pluck(:time, :value).collect { |time, value| [time.to_i, value.to_f] }
  end

  def save_value_line(e, prefix)
    line = StatusHistory.new
    line.time = @mytime
    line.key = "#{prefix}_#{e['arch']}"
    line.value = e['jobs']
    line.save
  end

  def update_workerstatus_cache
    # do not add hiding in here - this is purely for statistics
    ret=backend_get('/build/_workerstatus')
    data=Xmlhash.parse(ret)

    @mytime = Time.now.to_i
    Rails.cache.write('workerstatus', ret, expires_in: 3.minutes)
    Rails.cache.write('workerhash', data, expires_in: 3.minutes)
    StatusHistory.transaction do
      data.elements('blocked') do |e|
        save_value_line(e, 'blocked')
      end
      data.elements('waiting') do |e|
        save_value_line(e, 'waiting')
      end
      data.elements('partition') do |p|
        p.elements('daemon') do |daemon|
          parse_daemon_infos(daemon)
        end
      end
      parse_worker_infos(data)
    end
    ret
  end

  def parse_daemon_infos(daemon)
    return unless daemon['type'] == 'scheduler'
    arch = daemon['arch']
    # FIXME2.5: The current architecture model is a gross hack, not connected at all
    #           to the backend config.
    a=Architecture.find_by_name(arch)
    if a
      a.available=true
      a.save
    end
    queue = daemon.get('queue')
    return unless queue
    StatusHistory.create :time => @mytime, :key => "squeue_high_#{arch}", :value => queue['high'].to_i
    StatusHistory.create :time => @mytime, :key => "squeue_next_#{arch}", :value => queue['next'].to_i
    StatusHistory.create :time => @mytime, :key => "squeue_med_#{arch}", :value => queue['med'].to_i
    StatusHistory.create :time => @mytime, :key => "squeue_low_#{arch}", :value => queue['low'].to_i
  end

  def parse_worker_infos(data)
    allworkers = Hash.new
    workers = Hash.new
    %w{building idle}.each do |state|
      data.elements(state) do |e|
        id=e['workerid']
        if workers.has_key? id
          logger.debug 'building+idle worker'
          next
        end
        workers[id] = 1
        key = state + '_' + e['hostarch']
        allworkers["building_#{e['hostarch']}"] ||= 0
        allworkers["idle_#{e['hostarch']}"] ||= 0
        allworkers[key] = allworkers[key] + 1
      end
    end

    allworkers.each do |key, value|
      line = StatusHistory.new
      line.time = @mytime
      line.key = key
      line.value = value
      line.save
    end
  end

  # move to models?
  def role_from_cache(role_id)
    @rolecache[role_id] || (@rolecache[role_id] = Role.find(role_id).title)
  end

  def user_from_cache(user_id)
    @usercache[user_id] || (@usercache[user_id] = User.find(user_id).login)
  end

  def group_from_cache(group_id)
    @groupcache[group_id] || (@groupcache[group_id] = Group.find(group_id).title)
  end

  def find_relationships_for_packages(packages)
    package_hash = Hash.new
    packages.each_value do |p|
      package_hash[p.package_id] = p
      if p.develpack
        package_hash[p.develpack.package_id] = p.develpack
      end
    end
    @rolecache = {}
    @usercache = {}
    @groupcache = {}
    relationships = Relationship.where(package_id: package_hash.keys).pluck(:package_id, :user_id, :group_id, :role_id)
    relationships.each do |package_id, user_id, group_id, role_id|
      if user_id
        package_hash[package_id].add_person(user_from_cache(user_id),
                                            role_from_cache(role_id))
     else
        package_hash[package_id].add_group(group_from_cache(group_id),
                                           role_from_cache(role_id))
      end
    end
  end

  def project
    dbproj = Project.get_by_name(params[:project])
    @packages = ProjectStatusHelper.calc_status(dbproj)
    find_relationships_for_packages(@packages)
  end

  def bsrequest
    required_parameters :id
    Suse::Backend.start_test_backend if Rails.env.test?
    @id = params[:id]

    action = bsrequest_get_action

    sproj = Project.find_by_name!(action.source_project)
    tproj = Project.find_by_name!(action.target_project)
    spkg = sproj.packages.find_by_name!(action.source_package)

    dir = Directory.hashed(project: action.source_project,
                           package: action.source_package,
                           expand: 1, rev: action.source_rev)
    @result = PackageBuildStatus.new(spkg).result(target_project: tproj, srcmd5: dir['srcmd5'])
    render xml: render_to_string(partial: "bsrequest")
  end

  class NotFoundError < APIException
    setup 404
  end

  class MultipleNotSupported < APIException
  end

  class NotSubmitRequest < APIException
  end

  def bsrequest_get_action
    rel = BsRequestAction.where(bs_request_id: params[:id])
    if rel.count > 1
      raise MultipleNotSupported.new
    end
    action = rel.first
    raise NotFoundError.new unless action

    raise NotSubmitRequest.new 'Not submit' unless action.action_type == :submit
    action
  end

end
