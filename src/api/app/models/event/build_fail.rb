module Event
  class BuildFail < Build
    include BuildLogSupport

    self.message_bus_routing_key = 'package.build_fail'
    self.description = 'Package failed to build'
    receiver_roles :maintainer, :bugowner, :reader, :project_watcher, :package_watcher, :request_watcher

    create_jobs :report_to_scm_job

    self.notification_explanation = 'Receive notifications for build failures of packages for which you are...'

    def subject
      "Build failure of #{payload['project']}/#{payload['package']} in #{payload['repository']}/#{payload['arch']}"
    end

    def expanded_payload
      payload.merge('faillog' => reencode_faillog(faillog))
    end

    def custom_headers
      h = super
      h['X-OBS-Package'] = "#{payload['project']}/#{payload['package']}"
      h['X-OBS-Repository'] = "#{payload['repository']}/#{payload['arch']}"
      h['X-OBS-Worker'] = payload['workerid']
      h['X-OBS-Rebuild-Reason'] = payload['reason']
      h
    end

    def state
      'fail'
    end

    private

    def faillog
      size = get_size_of_log(payload['project'], payload['package'], payload['repository'], payload['arch'])
      offset = size - (18 * 1024)
      offset = 0 if offset.negative?
      log = raw_log_chunk(payload['project'], payload['package'], payload['repository'], payload['arch'], offset, size)
      log.encode!(invalid: :replace, undef: :replace, universal_newline: true)
      log = log.chomp.lines
      log = log.slice(-29, log.length) if log.length > 30
      log.join
    rescue Backend::Error
      nil
    end

    # Reencode the fail log replacing invalid UTF-8 characters with the default unicode replacement character: '\ufffd'
    # source: https://stackoverflow.com/a/24493972
    def reencode_faillog(faillog)
      faillog&.encode!('UTF-8', 'UTF-8', invalid: :replace)
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(16777215)
#  undone_jobs :integer          default(0)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#
