class Event < ActiveRecord::Base

  self.inheritance_column = 'eventtype'

  class << self
    attr_accessor :description
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
    super(created_at: attribs[:time])
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
    end
  end

  def set_payload(attribs, keys)
    values = {}
    keys.each do |k|
      k = k.to_s
      v = attribs.delete k
      values[k] = v unless v.nil?
    end
    self.payload = Yajl::Encoder.encode(values)
    # now check if anything but the default rails params are left
    check_left_attribs(attribs)
  end

  def payload
    @payload ||= Yajl::Parser.parse(read_attribute(:payload))
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
  self.description = 'Project is created'
  payload_keys :sender
end

class UpdateProjectConfigEvent < ProjectEvent
  self.description = 'Project _config was updated'
  payload_keys :sender, :files, :comment
end

class UndeleteProjectEvent < ProjectEvent
  self.description = 'Project was undeleted'
  payload_keys :comment, :sender
end

class UpdateProjectEvent < ProjectEvent
  self.description = 'Project meta was updated'
  payload_keys :sender
end

class DeleteProjectEvent < ProjectEvent
  self.description = 'Project was deleted'
  payload_keys :comment, :requestid, :sender
end

class RepoPublishStateEvent < Event
  self.description = 'Publish State of Repository has changed'
  payload_keys :project, :repo, :state
end

class RepoPublishedEvent < Event
  self.description = 'Repository was published'
  payload_keys :project, :repo
end

class PackageEvent < Event
  self.description = 'Package was touched'
  payload_keys :project, :package, :sender
end

class CreatePackageEvent < PackageEvent
  self.description = 'Package was created'
end

class UpdatePackageEvent < PackageEvent
  self.description = 'Package meta data was updated'
end

class UndeletePackageEvent < PackageEvent
  self.description = 'Package was undeleted'
  payload_keys :comment
end

class DeletePackageEvent < PackageEvent
  self.description = 'Package was deleted'
  payload_keys :comment, :requestid
end

class BranchCommandEvent < PackageEvent
  self.description = 'Package was branched'
  payload_keys :targetproject, :targetpackage, :user
end

class VersionChangeEvent < PackageEvent
  self.description = 'Package has changed its version'
  payload_keys :comment, :requestid, :files, :rev, :newversion, :user, :oldversion
end

class CommitEvent < PackageEvent
  self.description = 'New revision of a package was commited'
  payload_keys :project, :package, :comment, :user, :files, :rev, :requestid
end

class UploadEvent < PackageEvent
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
  self.description = 'Package has succeeded building'
end

class BuildFailEvent < BuildEvent
  self.description = 'Package has failed to build'
end

class BuildUnchangedEvent < BuildEvent
  self.description = 'Package has succeeded building with unchanged result'
end

class RequestEvent < Event
  self.description = 'Request was updated'
  self.abstract_class = true
  payload_keys :author, :comment, :description, :id, :oldstate, :sender,
               :sourceproject, :sourcepackage, :state, :targetproject, :targetpackage, :type, :when, :who,
               :deleteproject, :deletepackage, :person, :role, :sourcerevision
end

class RequestAcceptedEvent < RequestEvent
  self.description = 'Request was accepted'
end

class RequestChangeEvent < RequestEvent
  self.description = 'Request XML was updated (admin only)'
end

class RequestCreateEvent < RequestEvent
  self.description = 'Request created'
end

class RequestDeclinedEvent < RequestEvent
  self.description = 'Request declined'
end

class RequestDeleteEvent < RequestEvent
  self.description = 'Request was deleted (admin only)'
end

class RequestReviewerAddedEvent < RequestEvent
  self.description = 'Reviewer was added to a request'
  payload_keys :newreviewer
end

class RequestReviewerGroupAddedEvent < RequestEvent
  self.description = 'Review for a group was added to a request'
  payload_keys :newreviewer_group
end

class RequestReviewerPackageAddedEvent < RequestEvent
  self.description = 'Review for package maintainers added to a request'
  payload_keys :newreviewer_project, :newreviewer_package
end

class RequestReviewerProjectAddedEvent < RequestEvent
  self.description = 'Review for project maintainers added to a request'
  payload_keys :newreviewer_project
end

class RequestRevokedEvent < RequestEvent
  self.description = 'Request was revoked'
end

class RequestStatechangeEvent < RequestEvent
  self.description = 'Request state was changed'
  payload_keys :oldstate
end

class ReviewAcceptedEvent < RequestEvent
  self.description = 'Request was accepted'
end

class ReviewDeclinedEvent < RequestEvent
  self.description = 'Request was declined'
end
