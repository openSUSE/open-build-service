module Event
  class BuildFail < Build
    include BuildLogSupport

    self.description = 'Package has failed to build'
    receiver_roles :maintainer, :bugowner, :reader, :watcher
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.build_fail"
    end

    def subject
      "Build failure of #{payload['project']}/#{payload['package']} in #{payload['repository']}/#{payload['arch']}"
    end

    def faillog
      begin
        size = get_size_of_log(payload['project'], payload['package'], payload['repository'], payload['arch'])
        offset = size - 18 * 1024
        offset = 0 if offset < 0
        log = raw_log_chunk(payload['project'], payload['package'], payload['repository'], payload['arch'], offset, size)
        begin
          log.encode!(invalid: :replace, undef: :replace, universal_newline: true)
        rescue Encoding::UndefinedConversionError
          # encode is documented not to throw it if undef: is :replace, but at least we tried - and ruby 1.9.3 is buggy
        end
        log = log.chomp.lines
        log = log.slice(-29, log.length) if log.length > 30
        log.join
      rescue ActiveXML::Transport::Error
        nil
      end
    end

    def expanded_payload
      payload.merge('faillog' => faillog)
    end

    def custom_headers
      h = super
      h['X-OBS-Package'] = "#{payload['project']}/#{payload['package']}"
      h['X-OBS-Repository'] = "#{payload['repository']}/#{payload['arch']}"
      h['X-OBS-Worker'] = payload['workerid']
      h['X-OBS-Rebuild-Reason'] = payload['reason']
      h
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id             :integer          not null, primary key
#  eventtype      :string(255)      not null, indexed
#  payload        :text(65535)
#  created_at     :datetime         indexed
#  updated_at     :datetime
#  project_logged :boolean          default(FALSE), indexed
#  undone_jobs    :integer          default(0)
#  mails_sent     :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at      (created_at)
#  index_events_on_eventtype       (eventtype)
#  index_events_on_mails_sent      (mails_sent)
#  index_events_on_project_logged  (project_logged)
#
