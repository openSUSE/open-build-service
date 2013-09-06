class Event::Build < Event::Package
  self.description = 'Package has finished building'
  self.abstract_class = true
  payload_keys :repository, :arch, :disturl, :release, :file, :versrel, :readytime, :srcmd5,
               :srcserver, :rev, :revtime, :job, :reason, :bcnt, :needed, :path, :reposerver,
               :subpack, :verifymd5, :debuginfo, :constraintsmd5, :hostarch, :followupfile
end

class Event::BuildSuccess < Event::Build
  self.raw_type = 'BUILD_SUCCESS'
  self.description = 'Package has succeeded building'
end

class Event::BuildFail < Event::Build
  self.raw_type = 'BUILD_FAIL'
  self.description = 'Package has failed to build'
end

class Event::BuildUnchanged < Event::Build
  self.raw_type = 'BUILD_UNCHANGED'
  self.description = 'Package has succeeded building with unchanged result'
end
