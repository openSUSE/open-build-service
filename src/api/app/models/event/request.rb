class Event::Request < ::Event::Base
  self.description = 'Request was updated'
  self.abstract_class = true
  payload_keys :author, :comment, :description, :number, :actions, :state, :when, :who
  shortenable_key :description

  DiffLimit = 120

  def self.message_number(number)
    "<obs-request-#{number}@#{message_domain}>"
  end

  def my_message_number
    Event::Request.message_number(payload['number'])
  end

  def originator
    payload_address('who')
  end

  def custom_headers
    mid = my_message_number
    h = super
    h['In-Reply-To'] = mid
    h['References'] = mid
    h['X-OBS-Request-Creator'] = payload['author']
    h['X-OBS-Request-Id'] = payload['number']
    h['X-OBS-Request-State'] = payload['state']

    h.merge(headers_for_actions)
  end

  def headers_for_actions
    ret = {}
    payload['actions'].each_with_index do |a, index|
      if payload['actions'].length == 1 || index.zero?
        suffix = 'X-OBS-Request-Action'
      else
        suffix = "X-OBS-Request-Action-#{index}"
      end

      ret[suffix + '-type'] = a['type']
      if a['targetpackage']
        ret[suffix + '-target'] = "#{a['targetproject']}/#{a['targetpackage']}"
      elsif a['targetrepository']
        ret[suffix + '-target'] = "#{a['targetproject']}/#{a['targetrepository']}"
      elsif a['targetproject']
        ret[suffix + '-target'] = a['targetproject']
      end
      if a['sourcepackage']
        ret[suffix + '-source'] = "#{a['sourceproject']}/#{a['sourcepackage']}"
      elsif a['sourceproject']
        ret[suffix + '-source'] = a['sourceproject']
      end
    end
    ret
  end

  def actions_summary
    BsRequest.actions_summary(payload)
  end

  def calculate_diff(a)
    return if a['type'] != 'submit'
    raise 'We need action_id' unless a['action_id']
    action = BsRequestAction.find a['action_id']
    begin
      action.sourcediff(view: nil, withissues: 0)
    rescue BsRequestAction::DiffError
      return # can't help
    end
  end

  def source_from_remote?
    payload['actions'].any? { |action| Project.unscoped.is_remote_project?(action['sourceproject'], true) }
  end

  def payload_with_diff
    return payload if source_from_remote?

    ret = payload
    payload['actions'].each do |a|
      diff = calculate_diff(a)
      next unless diff
      diff = diff.lines
      dl = diff.length
      if dl > DiffLimit
        diff = diff[0..DiffLimit]
        diff << "[cut #{dl - DiffLimit} lines to limit mail size]"
      end
      a['diff'] = diff.join
    end
    ret
  end

  def reviewers
    ret = []
    BsRequest.find_by_number(payload['number']).reviews.each do |r|
      ret.concat(r.users_and_groups_for_review)
    end
    ret.uniq
  end

  def creators
    [User.find_by_login(payload['author'])]
  end

  def action_maintainers(prjname, pkgname)
    ret = []
    payload['actions'].each do |a|
      ret.concat _roles('maintainer', a[prjname], a[pkgname])
    end
    ret.uniq
  end

  def target_maintainers
    action_maintainers('targetproject', 'targetpackage')
  end

  def source_maintainers
    action_maintainers('sourceproject', 'sourcepackage')
  end

  def target_watchers
    find_watchers('targetproject')
  end

  def source_watchers
    find_watchers('sourceproject')
  end

  private

  def find_watchers(project_key)
    project_names = payload['actions'].map { |action| action[project_key] }.uniq
    projects = Project.where(name: project_names).joins(watched_projects: :user)
    projects.flat_map { |project| project.watched_projects.map(&:user) }
  end
end

class Event::RequestChange < Event::Request
  self.description = 'Request XML was updated (admin only)'
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.request.change"
  end
end

class Event::RequestCreate < Event::Request
  self.description = 'Request created'
  receiver_roles :source_maintainer, :target_maintainer, :source_watcher, :target_watcher
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.request.create"
  end

  def custom_headers
    base = super
    # we're the one they mean
    base.delete('In-Reply-To')
    base.delete('References')
    base.merge({'Message-ID' => my_message_number})
  end

  def subject
    "Request #{payload['number']} created by #{payload['who']} (#{actions_summary})"
  end

  def expanded_payload
    payload_with_diff
  end
end

class Event::RequestDelete < Event::Request
  self.description = 'Request was deleted (admin only)'
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.request.delete"
  end
end

class Event::RequestStatechange < Event::Request
  self.description = 'Request state was changed'
  payload_keys :oldstate
  receiver_roles :source_maintainer, :target_maintainer, :creator, :reviewer, :source_watcher, :target_watcher
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.request.state_change"
  end

  def subject
    "Request #{payload['number']} changed to #{payload['state']} (#{actions_summary})"
  end
end

class Event::ReviewWanted < Event::Request
  self.description = 'Review was created'

  payload_keys :reviewers, :by_user, :by_group, :by_project, :by_package
  receiver_roles :reviewer
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.request.review_wanted"
  end

  def subject
    "Request #{payload['number']} requires review (#{actions_summary})"
  end

  def expanded_payload
    payload_with_diff
  end

  def custom_headers
    h = super
    if payload['by_user']
      h['X-OBS-Review-By_User'] = payload['by_user']
    elsif payload['by_group']
      h['X-OBS-Review-By_Group'] = payload['by_group']
    elsif payload['by_package']
      h['X-OBS-Review-By_Package'] = "#{payload['by_project']}/#{payload['by_package']}"
    else
      h['X-OBS-Review-By_Project'] = payload['by_project']
    end
    h
  end

  # for review_wanted we ignore all the other reviews
  def reviewers
    User.where(id: payload["reviewers"].map { |r| r['user_id'] }) +
        Group.where(id: payload["reviewers"].map { |r| r['group_id'] })
  end
end
