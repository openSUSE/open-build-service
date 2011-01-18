class DomainCacheStore < ActiveSupport::Cache::Store

  def initialize(*store_option)
    @cache = ActiveSupport::Cache.lookup_store(store_option)
    @domain = ':'
  end

  def set_domain(domain = "")
    @domain = domain + ':'
  end

  def read(key, options = nil)
    @cache.read(mkkey(key, options), options)
  end

  def write(key, value, options = nil)
    @cache.write(mkkey(key, options), value, options)
  end

  def delete(key, options = nil)
    @cache.delete(mkkey(key, options), options)
  end

  def exist?(key, options = nil)
    @cache.exist?(mkkey(key, options), options)
  end

  def clear
    @cache.clear
  end

  private
    def mkkey(key, options)
      options && options[:shared] ? ':' + key : @domain + key
    end
end
