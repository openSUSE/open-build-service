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
