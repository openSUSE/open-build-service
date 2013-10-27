class Architecture < ActiveRecord::Base

#
# FIXME3.0: This controller is obsolete and will be removed
#           Do not add new stuff here!
#


  has_many :repository_architectures, inverse_of: :architecture
  has_many :repositories, :through => :repository_architectures
  
  has_many :download_stats
  has_many :downloads

  has_many :flags

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

