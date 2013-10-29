module Event

  class Package < Base
    self.description = 'Package was touched'
    payload_keys :project, :package, :sender
  end

  class CreatePackage < Package
    self.raw_type = 'SRCSRV_CREATE_PACKAGE'
    self.description = 'Package was created'

    create_jobs :cleanup_cache_lines
  end

  class UpdatePackage < Package
    self.raw_type = 'SRCSRV_UPDATE_PACKAGE'
    self.description = 'Package meta data was updated'
  end

  class UndeletePackage < Package
    self.raw_type = 'SRCSRV_UNDELETE_PACKAGE'
    self.description = 'Package was undeleted'
    payload_keys :comment

    create_jobs :cleanup_cache_lines, :update_backend_infos
  end

  class DeletePackage < Package
    self.raw_type = 'SRCSRV_DELETE_PACKAGE'
    self.description = 'Package was deleted'
    payload_keys :comment, :requestid

    create_jobs :cleanup_cache_lines
  end

  class BranchCommand < Package
    self.raw_type = 'SRCSRV_BRANCH_COMMAND'
    self.description = 'Package was branched'
    payload_keys :targetproject, :targetpackage, :user
  end

  class VersionChange < Package
    self.raw_type = 'SRCSRV_VERSION_CHANGE'
    self.description = 'Package has changed its version'
    payload_keys :comment, :requestid, :files, :rev, :newversion, :user, :oldversion
  end

  class Commit < Package
    self.raw_type = 'SRCSRV_COMMIT'
    self.description = 'New revision of a package was commited'
    payload_keys :project, :package, :comment, :user, :files, :rev, :requestid

    create_jobs :update_backend_infos
  end

  class Upload < Package
    self.raw_type = 'SRCSRV_UPLOAD'
    self.description = 'Package sources were uploaded'
    payload_keys :project, :package, :comment, :filename, :requestid, :target, :user
  end

end
