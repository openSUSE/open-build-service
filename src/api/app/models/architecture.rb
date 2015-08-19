class Architecture < ActiveRecord::Base

  # This class provides all existing architectures known to OBS

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

  after_save 'Architecture.discard_cache'
  after_destroy 'Architecture.discard_cache'
end

