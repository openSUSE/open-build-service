class BsRole < ActiveRecord::Base

  @cache = Hash.new
  find(:all).each do |role|
    @cache[role.title] = role
  end

  class << self
    def rolecache
      @cache
    end
  end

  def rolecache
    self.class.rolecache
  end

  def after_create
    logger.debug "updating role cache (new role '#{title}', id \##{id})"
    rolecache[title] = self
  end

  def after_update
    logger.debug "updating role cache (role name for id \##{id} changed to '#{title}')"
    rolecache.each do |k,v|
      if v.id = id
        rolecache.delete k
        break
      end
    end
    rolecache[title] = self
  end

  def after_destroy
    logger.debug "updating role cache (role '#{title}' deleted)"
    rolecache.delete title
  end
end
