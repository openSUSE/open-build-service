class CacheLine < ApplicationRecord
  # this function is a wrapper around Rails.cache that makes sure the cache key
  # is written in the cache_lines table so a event hook can wipe the cache
  def self.fetch(key, opts = {})
    cache_key = expanded_key(key)
    cont = Rails.cache.read(cache_key)
    return cont if cont

    cont = yield
    Rails.cache.write(cache_key, cont)
    begin
      CacheLine.create key: cache_key,
                       project: opts[:project],
                       package: opts[:package],
                       request: opts[:request]
    rescue ActiveRecord::StatementInvalid, Mysql2::Error
      # just don't cache in error, may caused by too large key
    end
    cont
  end

  def self.cleanup(rel)
    rel.each do |r|
      Rails.cache.delete(r.key)
    end
    rel.delete_all
  end

  def self.cleanup_package(project, package)
    cleanup(CacheLine.where(project: project, package: package))
  end

  def self.cleanup_project(project)
    cleanup(CacheLine.where(project: project))
  end

  def self.cleanup_request(request)
    cleanup(CacheLine.where(request: request))
  end

  # copied from (MIT) ActiveSupport::Cache
  # Expand key to be a consistent string value. Invoke +cache_key+ if
  # object responds to +cache_key+. Otherwise, +to_param+ method will be
  # called. If the key is a Hash, then keys will be sorted alphabetically.
  def self.expanded_key(key) # :nodoc:
    return key.cache_key.to_s if key.respond_to?(:cache_key)

    case key
      when Array
        if key.size > 1
          key = key.collect { |element| expanded_key(element) }
        else
          key = key.first
        end
      when Hash
        key = key.sort_by { |k, _| k.to_s }.collect { |k, v| "#{k}=#{v}" }
    end

    key.to_param
  end
end

