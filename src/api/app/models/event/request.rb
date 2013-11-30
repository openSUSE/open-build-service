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

  def custom_headers
    mid = my_message_id
    super.merge({'In-Reply-To' => mid, 'References' => mid})
  end
end

class Event::RequestChange < Event::Request
  self.raw_type = "SRCSRV_REQUEST_CHANGE"
  self.description = 'Request XML was updated (admin only)'
end

class Event::RequestCreate < Event::Request
  self.raw_type = "SRCSRV_REQUEST_CREATE"
  self.description = 'Request created'

  def custom_headers
    base = super
    # we're the one they mean
    base.delete('In-Reply-To')
    base.delete('References')
    base.merge({'Message-ID' => my_message_id})
  end

  def subject
    subj = "Request #{payload['id']} created by #{payload['who']}: "
    actions_summary = []
    payload['actions'].each do |a|
      str = "#{a['type']} #{a['targetproject']}"
      str += "/#{a['targetpackage']}" if a['targetpackage']
      actions_summary << str
    end
    subj + actions_summary.join(', ')
  end
end

class Event::RequestDelete < Event::Request
  self.raw_type = "SRCSRV_REQUEST_DELETE"
  self.description = 'Request was deleted (admin only)'
end

class Event::RequestStatechange < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_STATECHANGE'
  self.description = 'Request state was changed'
  payload_keys :oldstate

  def subject
    "Request state of #{payload['id']} changed to #{payload['state']}"
  end
end

