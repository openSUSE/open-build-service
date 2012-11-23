class Architecture < ActiveRecord::Base

  has_many :repository_architectures
  has_many :repositories, :through => :repository_architectures
  
  has_many :download_stats
  has_many :downloads

  has_many :flags

  attr_accessible :available, :recommended, :name

  def self.discard_cache
    Rails.cache.delete("archcache")
  end

  def self.archcache
    return Rails.cache.fetch("archcache") do
      ret = Hash.new
      Architecture.all.each do |arch|
        ret[arch.name] = arch
      end
      ret
    end
  end

  def archcache
    Architecture.archcache
  end

  after_save 'Architecture.discard_cache'
  after_destroy 'Architecture.discard_cache'
end

