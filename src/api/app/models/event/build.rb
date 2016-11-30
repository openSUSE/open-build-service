class Event::Build < Event::Package
  self.description = 'Package has finished building'
  self.abstract_class = true
  payload_keys :repository, :arch, :release, :readytime, :srcmd5,
               :rev, :reason, :bcnt, :verifymd5, :hostarch, :starttime, :endtime, :workerid, :versrel, :previouslyfailed

  def my_message_id
    # we put the verifymd5 sum in the message id, so new checkins get new thread, but it doesn't have to be very correct
    md5 = payload.fetch('verifymd5', 'NOVERIFY')[0..6]
    mid = Digest::MD5.hexdigest("#{payload['project']}-#{payload['package']}-#{payload['repository']}-#{md5}")
    "<build-#{mid}@#{self.class.message_domain}>"
  end

  def custom_headers
    mid = my_message_id
    h = super
    h['In-Reply-To'] = mid
    h['References'] = mid
    h
  end
end

class Event::BuildSuccess < Event::Build
  self.raw_type = 'BUILD_SUCCESS'
  self.description = 'Package has succeeded building'
end

class Event::BuildFail < Event::Build
  include BuildLogSupport

  self.raw_type = 'BUILD_FAIL'
  self.description = 'Package has failed to build'
  receiver_roles :maintainer, :bugowner, :reader

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

class Event::BuildUnchanged < Event::Build
  # no raw_type as it should not go to plugins
  self.description = 'Package has succeeded building with unchanged result'
end
