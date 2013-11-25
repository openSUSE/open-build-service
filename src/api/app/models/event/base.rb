module Event
  # This class represents some kind of event within the build service
  # that users (or services) would like to know about
  class Base < ActiveRecord::Base

    scope :not_in_queue, -> { where(queued: false) }

    self.inheritance_column = 'eventtype'
    self.table_name = 'events'

    class << self
      attr_accessor :description, :raw_type
      @payload_keys = nil
      @create_jobs = nil
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

      def create_jobs(*keys)
        # this function serves both for reading and setting
        if keys.empty?
          return @create_jobs || []
        end
        @create_jobs ||= []
        @create_jobs += keys
      end

      # make sure that subclasses can set shared attributes
      def inherited(subclass)
        super

        subclass.add_classname(self.name) unless self.name == 'Event::Base'
        subclass.payload_keys(*self.payload_keys)
        subclass.create_jobs(*self.create_jobs)
      end

    end

    # just for convenience
    def payload_keys
      self.class.payload_keys
    end

    def create_jobs
      self.class.create_jobs
    end

    def raw_type
      self.class.raw_type
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
      return false unless self.class.raw_type
      # tell the backend to tell the (old) plugins
      p = payload
      p['time'] = self.created_at.to_i
      logger.debug "notify_backend #{self.class.name} #{p.inspect}"
      ret = Suse::Backend.post("/notify_plugins/#{self.class.raw_type}",
                               Yajl::Encoder.encode(p),
                               'Content-Type' => 'application/json')
      return Xmlhash.parse(ret.body)['code'] == 'ok'
    end

    after_create :perform_create_jobs

    def perform_create_jobs
      self.create_jobs.each do |job|
        obj = job.to_s.camelize.safe_constantize.new(self)
        obj.delay.perform
      end
    end

    # to be overwritten in subclasses
    def subject
      'Build Service Notification'
    end

  end

end
