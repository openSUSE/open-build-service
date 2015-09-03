# This class provides all existing architectures known to OBS
class Architecture < ActiveRecord::Base
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  has_many :repository_architectures, inverse_of: :architecture
  has_many :repositories, :through => :repository_architectures
  has_many :flags

  #### Callbacks macros: before_save, after_save, etc.
  after_save 'Architecture.discard_cache'
  after_destroy 'Architecture.discard_cache'

  #### Scopes (first the default_scope macro if is used)
  scope :available, -> { where(available: 1) }

  #### Validations macros
  validates_uniqueness_of :name

  #### Class methods using self. (public and then private)

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

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def to_s
    name
  end
  #### Alias of methods

end
