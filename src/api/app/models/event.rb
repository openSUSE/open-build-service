class Event < ActiveRecord::Base

  self.inheritance_column = 'eventtype'

  class << self
    @payload_keys = nil

    def payload_keys(*keys)
      # this function serves both for reading and setting
      return @payload_keys if keys.empty?

      @payload_keys ||= []
      @payload_keys += keys
    end

    # make sure that subclasses can set shared payload keys
    def inherited(subclass)
      super
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
      v = attribs.delete k.to_s
      values[k] = v unless v.nil?
    end
    self.payload = Yajl::Encoder.encode(values)
    # now check if anything but the default rails params are left
    check_left_attribs(attribs)
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

class CreateProjectEvent < Event
  payload_keys :project, :sender
end

class VersionChangeEvent < Event
  payload_keys :package, :comment, :requestid, :files, :project, :rev, :newversion, :user, :oldversion
end

class BuildEvent < Event
  self.abstract_class = true
  payload_keys :verifymd5, :project, :disturl, :release, :file, :versrel, :readytime, :srcmd5,
               :srcserver, :rev, :repository, :arch, :revtime, :job, :reason, :package, :bcnt,
               :needed, :path, :reposerver, :subpack
end

class BuildSuccessEvent < BuildEvent
end

class BuildFailEvent < BuildEvent
end

class BuildUnchangedEvent < BuildEvent
end

class RepoPublishStateEvent < Event
  payload_keys :project, :state, :repo
end

class CommitEvent < Event
  payload_keys :comment, :user, :files, :rev, :package, :requestid, :project
end

class CreatePackageEvent < Event
  payload_keys :sender, :package, :project
end

class StartEvent < Event
end

class UpdateProjectConfigEvent < Event
  payload_keys :project, :sender, :files, :comment
end

class RepoPublishedEvent < Event
  payload_keys :project, :repo
end

class UpdatePackageEvent < Event
  payload_keys :package, :project, :sender
end

class BranchCommandEvent < Event
  payload_keys :package, :project, :targetpackage, :targetproject, :user
end

class DeletePackageEvent < Event
  payload_keys :comment, :package, :project, :requestid, :sender
end

class DeleteProjectEvent < Event
  payload_keys :comment, :project, :requestid, :sender
end

class RequestEvent < Event
  self.abstract_class = true
  payload_keys :author, :comment, :description, :id, :oldstate, :sender,
               :sourcepackage, :sourceproject, :state, :targetpackage, :targetproject, :type, :when, :who,
               :deletepackage, :deleteproject, :person, :role, :sourcerevision
end

class RequestAcceptedEvent < RequestEvent
end

class RequestChangeEvent < RequestEvent
end

class RequestCreateEvent < RequestEvent
end

class RequestDeclinedEvent < RequestEvent
end

class RequestDeleteEvent < RequestEvent
end

class RequestReviewerAddedEvent < RequestEvent
  payload_keys :newreviewer
end

class RequestReviewerGroupAddedEvent < RequestEvent
  payload_keys :newreviewer_group
end

class RequestReviewerPackageAddedEvent < RequestEvent
  payload_keys :newreviewer_package, :newreviewer_project
end

class RequestReviewerProjectAddedEvent < RequestEvent
  payload_keys :newreviewer_project
end

class RequestRevokedEvent < RequestEvent
end

class RequestStatechangeEvent < RequestEvent
  payload_keys :oldstate
end

class ReviewAcceptedEvent < RequestEvent
end

class ReviewDeclinedEvent < RequestEvent
end

class UndeletePackageEvent < Event
  payload_keys :comment, :package, :project, :sender
end

class UndeleteProjectEvent < Event
  payload_keys :comment, :project, :sender
end

class UpdateProjectEvent < Event
  payload_keys :project, :sender
end

class UploadEvent < Event
  payload_keys :comment, :filename, :package, :project, :requestid, :target, :user
end
