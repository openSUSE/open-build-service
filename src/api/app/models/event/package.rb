module Event
  class Package < Base
    self.description = 'Package was touched'
    payload_keys :project, :package, :sender
  end

  class CreatePackage < Package
    self.raw_type = 'SRCSRV_CREATE_PACKAGE'
    self.description = 'Package was created'
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.create"
    end

    def subject
      "New Package #{payload['project']}/#{payload['package']}"
    end
  end

  class UpdatePackage < Package
    self.raw_type = 'SRCSRV_UPDATE_PACKAGE'
    self.description = 'Package meta data was updated'
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.update"
    end
  end

  class UndeletePackage < Package
    self.raw_type = 'SRCSRV_UNDELETE_PACKAGE'
    self.description = 'Package was undeleted'
    payload_keys :comment
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.undelete"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      super(attribs, keys)
    end
    create_jobs :update_backend_infos_job
  end

  class DeletePackage < Package
    self.raw_type = 'SRCSRV_DELETE_PACKAGE'
    self.description = 'Package was deleted'
    payload_keys :comment, :requestid
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.delete"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      super(attribs, keys)
    end
  end

  class BranchCommand < Package
    self.raw_type = 'SRCSRV_BRANCH_COMMAND'
    self.description = 'Package was branched'
    payload_keys :targetproject, :targetpackage, :user
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.branch"
    end

    def subject
      "Package Branched: #{payload['project']}/#{payload['package']} => #{payload['targetproject']}/#{payload['targetpackage']}"
    end
  end

  class VersionChange < Package
    self.raw_type = 'SRCSRV_VERSION_CHANGE'
    self.description = 'Package has changed its version'
    payload_keys :comment, :requestid, :files, :rev, :newversion, :user, :oldversion
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.version_change"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      attribs['files'] = attribs['files'][0..800] unless attribs['files'].blank?
      super(attribs, keys)
    end
  end

  class Commit < Package
    self.raw_type = 'SRCSRV_COMMIT'
    self.description = 'New revision of a package was commited'
    payload_keys :project, :package, :comment, :user, :files, :rev, :requestid

    create_jobs :update_backend_infos_job
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.commit"
    end

    def subject
      "#{payload['project']}/#{payload['package']} r#{payload['rev']} commited"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      attribs['files'] = attribs['files'][0..800] unless attribs['files'].blank?
      super(attribs, keys)
    end
  end

  class Upload < Package
    self.raw_type = 'SRCSRV_UPLOAD'
    self.description = 'Package sources were uploaded'
    payload_keys :project, :package, :comment, :filename, :requestid, :target, :user
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.upload"
    end
  end

  class ServiceSuccess < Package
    self.raw_type = 'SRCSRV_SERVICE_SUCCESS'
    self.description = 'Package source service has succeeded'
    payload_keys :comment, :package, :project, :rev, :user, :requestid
    receiver_roles :maintainer, :bugowner
    create_jobs :update_backend_infos_job
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.service_success"
    end

    def subject
      "Source service succeeded of #{payload['project']}/#{payload['package']}"
    end

    def custom_headers
      h = super
      h['X-OBS-Package'] = "#{payload['project']}/#{payload['package']}"
      h
    end
  end

  class ServiceFail < Package
    self.raw_type = 'SRCSRV_SERVICE_FAIL'
    self.description = 'Package source service has failed'
    payload_keys :comment, :error, :package, :project, :rev, :user, :requestid
    receiver_roles :maintainer, :bugowner
    create_jobs :update_backend_infos_job
    after_commit :send_to_bus

    def self.message_bus_queue
      "#{Configuration.amqp_namespace}.package.service_fail"
    end

    def subject
      "Source service failure of #{payload['project']}/#{payload['package']}"
    end

    def custom_headers
      h = super
      h['X-OBS-Package'] = "#{payload['project']}/#{payload['package']}"
      h
    end

    def set_payload(attribs, keys)
      # limit the error string
      attribs['error'] = attribs['error'][0..800]
      super(attribs, keys)
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
#  queued         :boolean          default(FALSE), not null, indexed
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
#  index_events_on_queued          (queued)
#
