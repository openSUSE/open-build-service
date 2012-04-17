class Architecture < ActiveRecord::Base

  has_many :repository_architectures
  has_many :repositories, :through => :repository_architectures
  
  has_many :download_stats
  has_many :downloads

  has_many :flags

  attr_accessible :available, :recommended, :name

  def self.discard_cache
    @cache = nil
  end

  def self.archcache
    return @cache if @cache
    @cache = Hash.new
    Architecture.all.each do |arch|
      @cache[arch.name] = arch
    end
    return @cache
  end

  def archcache
    self.class.archcache
  end

  after_save 'Architecture.discard_cache'
  after_destroy 'Architecture.discard_cache'
end

