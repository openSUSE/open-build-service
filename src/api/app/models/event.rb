# This class represents some kind of event within the build service
# that users (or services) would like to know about
class Event < ActiveRecord::Base

  scope :not_in_queue, -> { where(queued: false) }

  self.inheritance_column = 'eventtype'

  class << self
    attr_accessor :description, :raw_type
    @payload_keys = nil
    @classnames = nil

    def classnames
      @classnames || [self.name]
    end

    def add_classname(name)
      @classnames ||= [self.name]
      @classnames << name
    end

    def payload_keys(*keys)
      # this function serves both for reading and setting
      return @payload_keys if keys.empty?

      @payload_keys ||= []
      @payload_keys += keys
    end

    # make sure that subclasses can set shared attributes
    def inherited(subclass)
      super

      subclass.add_classname(self.name) unless self.name == 'Event'
      subclass.payload_keys(*self.payload_keys)
    end
  end

  # just for convenience
  def payload_keys
    self.class.payload_keys
  end

  def initialize(attribs)
    super()
    self.created_at = attribs[:time] if attribs[:time]
    attribs.delete :eventtype
    attribs.delete :time

    set_payload(attribs, payload_keys)
  end

  def check_left_attribs(attribs)
    # remove default rails params
    attribs.delete 'format'
    attribs.delete 'action'
    attribs.delete 'controller'

    unless attribs.empty?
      na = []
      attribs.keys.each { |k| na << k.to_s }
      logger.debug "LEFT #{self.class.name} payload_keys :#{na.sort.join(', :')}"
      raise "LEFT #{self.class.name} payload_keys :#{na.sort.join(', :')} # #{attribs.inspect}"
    end
  end

  def set_payload(attribs, keys)
    values = {}
    keys.each do |k|
      # for internal events it's a symbol, for external ones a string, so try both
      v = attribs.delete k
      k = k.to_s
      v = attribs.delete k unless v
      values[k] = v unless v.nil?
    end
    self.payload = Yajl::Encoder.encode(values)
    # now check if anything but the default rails params are left
    check_left_attribs(attribs)
  end

  def payload
    @payload ||= Yajl::Parser.parse(read_attribute(:payload))
  end

  def notify_backend
    return false if self.queued
    self.queued = true
    begin
      self.save
    rescue ActiveRecord::StaleObjectError
      # if someone else saved it too, better don't send it
      return false
    end
    # tell the backend to tell the (old) plugins
    p = payload
    p['time'] = self.created_at.to_i
    logger.debug "notify_backend #{self.class.name} #{p.inspect}"
    ans = Xmlhash.parse(Suse::Backend.post("/notify/#{self.class.raw_type}?#{p.to_query}", '').body)
    return ans['code'] == 'ok'
  end

end

# performed from delayed job triggered by clockwork
class EventNotifyBackends

  def self.trigger_delayed_sent
    self.new.delay.send_not_in_queue
  end

  def send_not_in_queue
    Event.not_in_queue.each do |e|
      if !e.notify_backend
        # if something went wrong, we better stop the queueing here
        return
      end
    end
  end

end

class EventFactory
  def self.new_from_type(type, params)
    # as long as there is no overlap, all these Srcsrv prefixes only look silly
    type.gsub!(%r{^SRCSRV_}, '')
    begin
      (type.downcase.camelcase + 'Event').constantize.new params
    rescue NameError => e
      bt = e.backtrace.join("\n")
      Rails.logger.debug "NameError #{e.inspect} #{bt}"
      nil
    end
  end
end

class ProjectEvent < Event
  self.description = 'Project was touched'
  payload_keys :project
end

class CreateProjectEvent < ProjectEvent
  self.raw_type = 'SRCSRV_CREATE_PROJECT'
  self.description = 'Project is created'
  payload_keys :sender
end

class UpdateProjectConfigEvent < ProjectEvent
  self.raw_type = 'SRCSRV_UPDATE_PROJECT_CONFIG'
  self.description = 'Project _config was updated'
  payload_keys :sender, :files, :comment
end

class UndeleteProjectEvent < ProjectEvent
  self.raw_type = 'SRCSRV_UNDELETE_PROJECT'
  self.description = 'Project was undeleted'
  payload_keys :comment, :sender
end

class UpdateProjectEvent < ProjectEvent
  self.raw_type = 'SRCSRV_UPDATE_PROJECT'
  self.description = 'Project meta was updated'
  payload_keys :sender
end

class DeleteProjectEvent < ProjectEvent
  self.raw_type = 'SRCSRV_DELETE_PROJECT'
  self.description = 'Project was deleted'
  payload_keys :comment, :requestid, :sender
end

class RepoPublishStateEvent < Event
  self.raw_type = 'REPO_PUBLISH_STATE'
  self.description = 'Publish State of Repository has changed'
  payload_keys :project, :repo, :state
end

class RepoPublishedEvent < Event
  self.raw_type = 'REPO_PUBLISHED'
  self.description = 'Repository was published'
  payload_keys :project, :repo
end

class PackageEvent < Event
  self.description = 'Package was touched'
  payload_keys :project, :package, :sender
end

class CreatePackageEvent < PackageEvent
  self.raw_type = 'SRCSRV_CREATE_PACKAGE'
  self.description = 'Package was created'
end

class UpdatePackageEvent < PackageEvent
  self.raw_type = 'SRCSRV_UPDATE_PACKAGE'
  self.description = 'Package meta data was updated'
end

class UndeletePackageEvent < PackageEvent
  self.raw_type = 'SRCSRV_UNDELETE_PACKAGE'
  self.description = 'Package was undeleted'
  payload_keys :comment
end

class DeletePackageEvent < PackageEvent
  self.raw_type = 'SRCSRV_DELETE_PACKAGE'
  self.description = 'Package was deleted'
  payload_keys :comment, :requestid
end

class BranchCommandEvent < PackageEvent
  self.raw_type = 'SRCSRV_BRANCH_COMMAND'
  self.description = 'Package was branched'
  payload_keys :targetproject, :targetpackage, :user
end

class VersionChangeEvent < PackageEvent
  self.raw_type = 'SRCSRV_VERSION_CHANGE'
  self.description = 'Package has changed its version'
  payload_keys :comment, :requestid, :files, :rev, :newversion, :user, :oldversion
end

class CommitEvent < PackageEvent
  self.raw_type = 'SRCSRV_COMMIT'
  self.description = 'New revision of a package was commited'
  payload_keys :project, :package, :comment, :user, :files, :rev, :requestid
end

class UploadEvent < PackageEvent
  self.raw_type = 'SRCSRV_UPLOAD'
  self.description = 'Package sources were uploaded'
  payload_keys :project, :package, :comment, :filename, :requestid, :target, :user
end

class BuildEvent < PackageEvent
  self.description = 'Package has finished building'
  self.abstract_class = true
  payload_keys :repository, :arch, :disturl, :release, :file, :versrel, :readytime, :srcmd5,
               :srcserver, :rev, :revtime, :job, :reason, :bcnt, :needed, :path, :reposerver,
               :subpack, :verifymd5
end

class BuildSuccessEvent < BuildEvent
  self.raw_type = 'BUILD_SUCCESS'
  self.description = 'Package has succeeded building'
end

class BuildFailEvent < BuildEvent
  self.raw_type = 'BUILD_FAIL'
  self.description = 'Package has failed to build'
end

class BuildUnchangedEvent < BuildEvent
  self.raw_type = 'BUILD_UNCHANGED'
  self.description = 'Package has succeeded building with unchanged result'
end

class RequestEvent < Event
  self.description = 'Request was updated'
  self.abstract_class = true
  payload_keys :author, :comment, :description, :id, :actions, :state, :when
end

class RequestAcceptedEvent < RequestEvent
  self.raw_type = 'SRCSRV_REQUEST_ACCEPTED'
  self.description = 'Request was accepted'
  payload_keys :oldstate
end

class RequestChangeEvent < RequestEvent
  self.raw_type = "SRCSRV_REQUEST_CHANGE"
  self.description = 'Request XML was updated (admin only)'
end

class RequestCreateEvent < RequestEvent
  self.raw_type = "SRCSRV_REQUEST_CREATE"
  self.description = 'Request created'
end

class RequestDeclinedEvent < RequestEvent
  self.raw_type = 'SRCSRV_REQUEST_DECLINED'
  self.description = 'Request declined'
  payload_keys :oldstate
end

class RequestDeleteEvent < RequestEvent
  self.raw_type = "SRCSRV_REQUEST_DELETE"
  self.description = 'Request was deleted (admin only)'
end

class RequestReviewerAddedEvent < RequestEvent
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_ADDED"
  self.description = 'Reviewer was added to a request'
  payload_keys :newreviewer
end

class RequestReviewerGroupAddedEvent < RequestEvent
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_GROUP_ADDED"
  self.description = 'Review for a group was added to a request'
  payload_keys :newreviewer_group
end

class RequestReviewerPackageAddedEvent < RequestEvent
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_PACKAGE_ADDED"
  self.description = 'Review for package maintainers added to a request'
  payload_keys :newreviewer_project, :newreviewer_package
end

class RequestReviewerProjectAddedEvent < RequestEvent
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_PROJECT_ADDED"
  self.description = 'Review for project maintainers added to a request'
  payload_keys :newreviewer_project
end

class RequestRevokedEvent < RequestEvent
  self.raw_type = 'SRCSRV_REQUEST_REVOKED'
  self.description = 'Request was revoked'
  payload_keys :oldstate
end

class RequestStatechangeEvent < RequestEvent
  self.raw_type = 'SRCSRV_REQUEST_STATECHANGE'
  self.description = 'Request state was changed'
  payload_keys :oldstate
end

class ReviewAcceptedEvent < RequestEvent
  self.raw_type = 'SRCSRV_REVIEW_ACCEPTED'
  self.description = 'Request was accepted'
end

class ReviewDeclinedEvent < RequestEvent
  self.raw_type = 'SRCSRV_REVIEW_DECLINED'
  self.description = 'Request was declined'
end
