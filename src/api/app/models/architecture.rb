class Architecture < ActiveRecord::Base
  has_and_belongs_to_many :repositories

  @cache = Hash.new
  find(:all).each do |arch|
    @cache[arch.name] = arch
  end

  class << self
    def archcache
      @cache
    end
  end

  def archcache
    self.class.archcache
  end

  def after_create
    logger.debug "updating arch cache (new arch '#{name}', id \##{id})"
    archcache[name] = self
  end

  def after_update
    logger.debug "updating arch cache (arch name for id \##{id} changed to '#{name}')"
    archcache.each do |k,v|
      if v.id = id
        archcache.delete k
        break
      end
    end
    archcache[name] = self
  end

  def after_destroy
    logger.debug "updating arch cache (arch '#{name}' deleted)"
    rolecache.delete name
  end
end
