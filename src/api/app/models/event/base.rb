# This class represents some kind of event within the build service
# that users (or services) would like to know about
module Event
  class Base < ApplicationRecord
    scope :not_in_queue, -> { where(queued: false) }

    self.inheritance_column = 'eventtype'
    self.table_name = 'events'

    class << self
      attr_accessor :description, :raw_type
      @payload_keys = nil
      @create_jobs = nil
      @classnames = nil
      @receiver_roles = nil

      def notification_events
        %w(
          Event::RequestCreate Event::RequestStatechange
          Event::CommentForProject Event::CommentForPackage
          Event::CommentForRequest Event::BuildFail
          Event::ReviewWanted Event::ServiceFail
        ).map(&:constantize)
      end

      def classnames
        @classnames || [name]
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

      def create_jobs(*keys)
        # this function serves both for reading and setting
        if keys.empty?
          return @create_jobs || []
        end
        @create_jobs ||= []
        @create_jobs += keys
      end

      def receiver_roles(*keys)
        # this function serves both for reading and setting
        if keys.empty?
          return @receiver_roles || []
        end
        @receiver_roles ||= []
        @receiver_roles += keys
      end

      # make sure that subclasses can set shared attributes
      def inherited(subclass)
        super

        subclass.add_classname(name) unless name == 'Event::Base'
        subclass.payload_keys(*payload_keys)
        subclass.create_jobs(*create_jobs)
        subclass.receiver_roles(*receiver_roles)
      end
    end

    # just for convenience
    def payload_keys
      self.class.payload_keys
    end

    def create_jobs
      self.class.create_jobs
    end

    def receiver_roles
      self.class.receiver_roles
    end

    def raw_type
      self.class.raw_type
    end

    def initialize(_attribs)
      attribs = _attribs.dup
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

      return if attribs.empty?

      na = []
      attribs.keys.each { |k| na << k.to_s }
      logger.debug "LEFT #{self.class.name} payload_keys :#{na.sort.join(', :')}"
      raise "LEFT #{self.class.name} payload_keys :#{na.sort.join(', :')} # #{attribs.inspect}"
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
      return false if queued
      self.queued = true
      begin
        save
      rescue ActiveRecord::StaleObjectError
        # if someone else saved it too, better don't send it
        return false
      end
      return false unless self.class.raw_type
      # tell the backend to tell the (old) plugins
      p = payload
      p['time'] = created_at.to_i
      logger.debug "notify_backend #{self.class.name} #{p.inspect}"
      ret = Backend::Connection.post("/notify_plugins/#{self.class.raw_type}",
                                     Yajl::Encoder.encode(p),
                                     'Content-Type' => 'application/json')
      Xmlhash.parse(ret.body)['code'] == 'ok'
    end

    after_create :perform_create_jobs

    def perform_create_jobs
      self.undone_jobs = 0
      save
      Rails.logger.debug "PCJ #{inspect} #{create_jobs.inspect}"
      create_jobs.each do |job|
        eclass = job.to_s.camelize.safe_constantize
        raise "#{job.to_s.camelize} does not map to a constant" if eclass.nil?
        djob = eclass.new(self)
        raise("#{job.to_s.camelize} is not a CreateJob") unless djob.is_a?(CreateJob)
        opts = {}
        opts = { queue: eclass.job_queue } if eclass.methods.include? :job_queue
        Delayed::Job.enqueue djob, opts
        self.undone_jobs += 1
      end
      save if self.undone_jobs > 0
    end

    # to be overwritten in subclasses
    def subject
      'Build Service Notification'
    end

    def self.message_domain
      domain = URI.parse(::Configuration.obs_url)
      domain.host.downcase
    end

    # needs to return a hash (merge super)
    def custom_headers
      # not to break user's filters for now
      ret = {}
      ret['X-OBS-event-type'] = template_name # cheating
      if Rails.env.test?
        ret['Message-ID'] = "<notrandom@#{self.class.message_domain}>"
      else
        ret['Message-ID'] = "<#{Mail.random_tag}@#{self.class.message_domain}>"
      end
      ret
    end

    def subscribers
      EventFindSubscribers.new(self).subscribers
    end

    # to calculate expensive things we don't want to store in database (i.e. diffs)
    def expanded_payload
      payload
    end

    def payload_address(field)
      if payload[field]
        return User.find_by_login(payload[field])
      end
      nil
    end

    def originator
      payload_address('sender')
    end

    def template_name
      self.class.name.gsub('Event::', '').underscore
    end

    def obj_roles(obj, role)
      # old/deleted obj
      return [] unless obj || role.blank?

      rel = obj.relationships.where(role: Role.hashed[role])
      receivers = rel.map { |r| r.user_id ? r.user : r.group }
      if receivers.empty? && obj.respond_to?(:project)
        receivers = obj_roles(obj.project, role)
      end

      # for now we define develpackage maintainers as being maintainers too
      if obj.respond_to?(:develpackage)
        receivers.concat(obj_roles(obj.develpackage, role))
      end
      receivers
    end

    def maintainers
      Rails.logger.debug "Maintainers #{payload.inspect}"
      ret = _roles('maintainer', payload['project'], payload['package'])
      Rails.logger.debug "Maintainers ret #{ret.inspect}"
      ret
    end

    def bugowners
      Rails.logger.debug "Maintainers #{payload.inspect}"
      ret = _roles('bugowner', payload['project'], payload['package'])
      Rails.logger.debug "Maintainers ret #{ret.inspect}"
      ret
    end

    def readers
      Rails.logger.debug "Readers #{payload.inspect}"
      ret = _roles('reader', payload['project'])
      Rails.logger.debug "Readers ret #{ret.inspect}"
      ret
    end

    def _roles(role, project, package = nil)
      return [] unless project
      p = nil
      p = ::Package.find_by_project_and_name(project, package) if package
      p ||= ::Project.find_by_name(project)
      obj_roles(p, role)
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
#  lock_version   :integer          default(0), not null
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
