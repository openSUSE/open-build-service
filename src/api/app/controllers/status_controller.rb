require_dependency 'status_helper'

class StatusController < ApplicationController

  class PermissionDeniedError < APIException
    setup 403
  end

  def list_messages
    @messages = StatusMessage.alive.limit(params[:limit]).order('created_at DESC').includes(:user)
    @count = @messages.size
    render xml: render_to_string(partial: 'messages')
  end

  def show_message
    @messages = [StatusMessage.find(params[:id])]
    @count = 1
    render xml: render_to_string(partial: 'messages')
  end

  class CreatingMessagesError < APIException
  end

  def update_messages
    # check permissions
    unless permissions.status_message_create
      raise PermissionDeniedError.new 'message(s) cannot be created, you have not sufficient permissions'
    end

    new_messages = ActiveXML::Node.new(request.raw_post)

    if new_messages.has_element? 'message'
      # message(s) are wrapped in outer xml tag 'status_messages'
      new_messages.each_message do |msg|
        save_new_message(msg)
      end
    else
      # TODO: make use of a validator
      raise CreatingMessagesError.new "no message #{new_messages.dump_xml}" if new_messages.element_name != 'message'
      # just one message, NOT wrapped in outer xml tag 'status_messages'
      save_new_message(new_messages)
    end
    render_ok
  end

  def save_new_message(msg)
    message = StatusMessage.new
    message.message = msg.to_s
    message.severity = msg.value :severity
    message.user = User.current
    message.save!
  end

  def delete_message
    # check permissions
    unless permissions.status_message_create
      raise PermissionDeniedError.new 'message cannot be deleted, you have not sufficient permissions'
    end

    StatusMessage.find(params[:id]).delete
    render_ok
  end

  def workerstatus
    send_data WorkerStatus.hidden.dump_xml
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
    @packages = ProjectStatusCalculator.new(dbproj).calc_status
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
    render xml: render_to_string(partial: 'bsrequest')
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
