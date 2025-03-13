module Event
  class Build < Base
    include EventObjectPackage

    self.description = 'Package finished building'
    self.abstract_class = true
    payload_keys :project, :package, :sender, :repository, :arch, :release, :readytime, :srcmd5,
                 :rev, :reason, :bcnt, :verifymd5, :hostarch, :starttime, :endtime, :workerid, :versrel, :previouslyfailed, :successive_failcount, :buildtype

    def subject
      raise AbstractMethodCalled
    end

    def custom_headers
      mid = my_message_id
      h = super
      h['In-Reply-To'] = mid
      h['References'] = mid
      h
    end

    def metric_measurement
      'build'
    end

    def metric_tags
      {
        namespace: ::Project.find_by_name(payload['project'])&.maintained_namespace,
        worker: payload['workerid'],
        arch: payload['arch'],
        reason: reason,
        state: state,
        buildtype: payload['buildtype']
      }
    end

    def metric_fields
      {
        duration: duration_in_seconds,
        latency: latency_in_seconds,
        total: total_in_seconds
      }
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'Package',
                  notifiable_id: ::Package.find_by_project_and_name(payload['project'], payload['package'])&.id,
                  type: 'NotificationPackage')
    end

    def involves_hidden_project?
      Project.unscoped.find_by(name: payload['project'])&.disabled_for?('access', nil, nil)
    end

    private

    # The seconds spent building
    def duration_in_seconds
      payload['endtime'].to_i - payload['starttime'].to_i
    end

    # The seconds spent waiting for a build slot
    def latency_in_seconds
      payload['starttime'].to_i - payload['readytime'].to_i
    end

    # The seconds spent waiting and building
    def total_in_seconds
      payload['endtime'].to_i - payload['readytime'].to_i
    end

    def reason
      payload['reason'].parameterize.underscore
    end

    def my_message_id
      # we put the verifymd5 sum in the message id, so new checkins get new thread, but it doesn't have to be very correct
      md5 = payload.fetch('verifymd5', 'NOVERIFY')[0..6]
      mid = Digest::MD5.hexdigest("#{payload['project']}-#{payload['package']}-#{payload['repository']}-#{md5}")
      "<build-#{mid}@#{URI.parse(Configuration.obs_url).host.downcase}>"
    end
  end
end
