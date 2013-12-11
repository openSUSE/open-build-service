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
  self.raw_type = 'BUILD_FAIL'
  self.description = 'Package has failed to build'
  receiver_roles :maintainer
end

class Event::BuildUnchanged < Event::Build
  # no raw_type as it should not go to plugins
  self.description = 'Package has succeeded building with unchanged result'
end
