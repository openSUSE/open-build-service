class Event::Build < Event::Package
  self.description = 'Package has finished building'
  self.abstract_class = true
  payload_keys :repository, :arch, :release, :readytime, :srcmd5,
               :rev, :reason, :bcnt, :verifymd5, :hostarch, :starttime, :endtime, :workerid, :versrel
end

class Event::BuildSuccess < Event::Build
  self.raw_type = 'BUILD_SUCCESS'
  self.description = 'Package has succeeded building'
end

class Event::BuildFail < Event::Build
  include BuildLogSupport

  self.raw_type = 'BUILD_FAIL'
  self.description = 'Package has failed to build'
  receiver_roles :maintainer

  def subject
    "Build failure of #{payload['project']}/#{payload['package']} in #{payload['repository']}/#{payload['arch']}"
  end

  def faillog
    begin
      size = get_size_of_log(payload['project'], payload['package'], payload['repository'], payload['arch'])
      logger.debug('log size is %d' % size)
      offset = size - 18 * 1024
      offset = 0 if offset < 0
      log = get_log_chunk(payload['project'], payload['package'], payload['repository'], payload['arch'], offset, size).lines
      if log.length > 20
        log = log.slice(-19, log.length)
      end
      log.join
    rescue ActiveXML::Transport::NotFoundError => e
      logger.error "Got #{e.class}: #{e.message}; returning empty log."
      nil
    end
  end

  def expanded_payload
    payload.merge('faillog' => faillog)
  end

end

class Event::BuildUnchanged < Event::Build
  # no raw_type as it should not go to plugins
  self.description = 'Package has succeeded building with unchanged result'
end
