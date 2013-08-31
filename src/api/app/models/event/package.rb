class Event::Package < ::Event::Base
  self.description = 'Package was touched'
  payload_keys :project, :package, :sender
end

class Event::CreatePackage < Event::Package
  self.raw_type = 'SRCSRV_CREATE_PACKAGE'
  self.description = 'Package was created'
end

class Event::UpdatePackage < Event::Package
  self.raw_type = 'SRCSRV_UPDATE_PACKAGE'
  self.description = 'Package meta data was updated'
end

class Event::UndeletePackage < Event::Package
  self.raw_type = 'SRCSRV_UNDELETE_PACKAGE'
  self.description = 'Package was undeleted'
  payload_keys :comment
end

class Event::DeletePackage < Event::Package
  self.raw_type = 'SRCSRV_DELETE_PACKAGE'
  self.description = 'Package was deleted'
  payload_keys :comment, :requestid
end

class Event::BranchCommand < Event::Package
  self.raw_type = 'SRCSRV_BRANCH_COMMAND'
  self.description = 'Package was branched'
  payload_keys :targetproject, :targetpackage, :user
end

class Event::VersionChange < Event::Package
  self.raw_type = 'SRCSRV_VERSION_CHANGE'
  self.description = 'Package has changed its version'
  payload_keys :comment, :requestid, :files, :rev, :newversion, :user, :oldversion
end

class Event::Commit < Event::Package
  self.raw_type = 'SRCSRV_COMMIT'
  self.description = 'New revision of a package was commited'
  payload_keys :project, :package, :comment, :user, :files, :rev, :requestid
end

class Event::Upload < Event::Package
  self.raw_type = 'SRCSRV_UPLOAD'
  self.description = 'Package sources were uploaded'
  payload_keys :project, :package, :comment, :filename, :requestid, :target, :user
end
