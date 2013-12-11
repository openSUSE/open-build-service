class Event::Request < ::Event::Base
  self.description = 'Request was updated'
  self.abstract_class = true
  payload_keys :author, :comment, :description, :id, :actions, :state, :when, :who

  def self.message_id(id)
    domain = URI.parse(::Configuration.first.obs_url)
    "obs-request-#{id}@#{domain.host.downcase}"
  end

  def my_message_id
    Event::Request.message_id(payload['id'])
  end

  def originator
    payload_address('who') || mail_sender
  end

  def custom_headers
    mid = my_message_id
    h = super
    h['In-Reply-To'] = mid
    h['References'] = mid
    h['X-OBS-Request-Creator'] = payload['author']
    h['X-OBS-Request-Id'] = payload['id']
    h['X-OBS-Request-State'] = payload['state']

    payload['actions'].each_with_index do |a, index|
      if payload['actions'].length == 1 || index == 0
        suffix = 'X-OBS-Request-Action'
      else
        suffix = "X-OBS-Request-Action-#{index}"
      end

      h[suffix + '-type'] = a['type']
      if a['targetpackage']
        h[suffix + '-target'] = "#{a['targetproject']}/#{a['targetpackage']}"
      elsif a['targetproject']
        h[suffix + '-target'] = a['targetproject']
      end
      if a['sourcepackage']
        h[suffix + '-source'] = "#{a['sourceproject']}/#{a['sourcepackage']}"
      elsif a['sourceproject']
        h[suffix + '-source'] = a['sourceproject']
      end
    end

    h
  end

  def actions_summary
    ret = []
    payload['actions'].each do |a|
      str = "#{a['type']} #{a['targetproject']}"
      str += "/#{a['targetpackage']}" if a['targetpackage']
      ret << str
    end
    ret.join(', ')
  end

  def calculate_diff(a)
    return nil if a['type'] != 'submit'
    raise 'We need action_id' unless a['action_id']
    action = BsRequestAction.find a['action_id']
    begin
      action.sourcediff(view: nil, withissues: 0)
    rescue BsRequestAction::DiffError
      return nil # can't help
    end
  end

  DiffLimit = 200

  def payload_with_diff
    ret = payload
    payload['actions'].each do |a|
      diff = calculate_diff(a)
      next unless diff
      diff = diff.lines
      dl = diff.length
      if dl > DiffLimit
        diff = diff[0..DiffLimit]
        diff << "[cut #{dl-DiffLimit} lines to limit mail size]"
      end
      a['diff'] = diff.join
    end
    ret
  end

  def reviewers
    ret = []
    BsRequest.find(payload['id']).reviews.each do |r|
      ret.concat(r.users_for_review)
    end
    ret.uniq
  end

  def creator
    User.find_by_login(payload['author']).id
  end

  def target_maintainers
    ret = []
    payload['actions'].each do |a|
      ret.concat _maintainers(a['targetproject'], a['targetpackage'])
    end
    ret.uniq
  end
end

class Event::RequestChange < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_CHANGE'
  self.description = 'Request XML was updated (admin only)'
end

class Event::RequestCreate < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_CREATE'
  self.description = 'Request created'

  def custom_headers
    base = super
    # we're the one they mean
    base.delete('In-Reply-To')
    base.delete('References')
    base.merge({'Message-ID' => my_message_id})
  end

  def subject
    "#{payload['who']} created request #{payload['id']} (#{actions_summary})"
  end

  def expanded_payload
    payload_with_diff
  end
end

class Event::RequestDelete < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_DELETE'
  self.description = 'Request was deleted (admin only)'
end

class Event::RequestStatechange < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_STATECHANGE'
  self.description = 'Request state was changed'
  payload_keys :oldstate

  def subject
    "Request state of #{payload['id']} (#{actions_summary}) changed to #{payload['state']}"
  end
end

class Event::ReviewWanted < Event::Request
  self.description = 'Review was created'

  payload_keys :reviewers, :by_user, :by_group, :by_project, :by_package

  def subject
    "Review required for request #{payload['id']} (#{actions_summary})"
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
    payload['reviewers']
  end
end
