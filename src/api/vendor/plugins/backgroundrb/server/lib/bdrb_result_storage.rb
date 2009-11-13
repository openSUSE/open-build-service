module BackgrounDRb
  class ResultStorage
    attr_accessor :cache,:worker_name,:worker_key,:storage_type
    def initialize(worker_name,worker_key,storage_type = nil)
      @worker_name = worker_name
      @worker_key = worker_key
      @mutex = Mutex.new
      @storage_type = storage_type
      @cache = (@storage_type == 'memcache') ? memcache_instance : {}
    end

    # Initialize Memcache for result or object caching
    def memcache_instance
      require 'memcache'
      memcache_options = {
        :c_threshold => 10_000,
        :compression => true,
        :debug => false,
        :namespace => 'backgroundrb_result_hash',
        :readonly => false,
        :urlencode => false
      }
      t_cache = MemCache.new(memcache_options)
      t_cache.servers = BDRB_CONFIG[:memcache].split(',')
      t_cache
    end

    # generate key based on worker_name and worker_key
    # for local cache, there is no need of unique key
    def gen_key key
      if storage_type == 'memcache'
        key = [worker_name,worker_key,key].compact.join('_')
        key
      else
        key
      end
    end

    # fetch object from cache
    def [] key
      @mutex.synchronize { @cache[gen_key(key)] }
    end

    def []= key,value
      @mutex.synchronize { @cache[gen_key(key)] = value }
    end

    def delete key
      @mutex.synchronize { @cache.delete(gen_key(key)) }
    end

    def shift key
      val = nil
      @mutex.synchronize do
        val = @cache[key]
        @cache.delete(key)
      end
      return val
    end
  end
end

