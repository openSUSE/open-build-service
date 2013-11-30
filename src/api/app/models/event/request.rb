class Event::Request < ::Event::Base
  self.description = 'Request was updated'
  self.abstract_class = true
  payload_keys :author, :comment, :description, :id, :actions, :state, :when, :who

  def my_message_id
    domain = URI.parse(::Configuration.first.obs_url)
    "obs-request-#{payload['id']}@#{domain.host.downcase}"
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
    {'Message-ID' => my_message_id}.merge(super)
  end

  def subject
    "[#{payload['type']}-request #{payload['id']}] #{payload['targetproject']}/#{payload['targetpackage']}: created by #{payload['who']}%>"
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
    "[obs #{payload['type']}-request #{payload['id']}] #{payload['targetproject']}/#{payload['targetpackage']}: #{payload['state']} by #{payload['who']}"
  end
end

