class Tag < ActiveRecord::Base
  
  has_many :taggings, :dependent => :destroy
  has_many :db_projects, :through => :taggings,
  :conditions => "taggings.taggable_type = 'DbProject'"
  has_many :db_packages, :through => :taggings,
  :conditions => "taggings.taggable_type = 'DbPackage'"
  
  has_many :users, :through => :taggings

  attr_accessor :cached_count
  
  def before_save
  end
  
  
  def count(opt={})
    if @cached_count 
      #logger.debug "[TAG:] tag usage count is already calculated. count: #{@cached_count}"
      return @cached_count
    end
    
    if opt[:scope] == "by_given_tags"
      tags = opt[:tags]
      @cached_count = 0 
      tags.each do |tag|
        @cached_count = @cached_count + 1 if tag.name == self.name
      end
    elsif opt[:scope] == "user"
      user = opt[:user]
      #logger.debug "[TAG:] calculating user-dependent tag usage count"
      @cached_count ||= Tagging.count(:id,
                                      :conditions => ["tag_id = ? AND user_id = ?", self.id, user.id])
    else
      #logger.debug "[TAG:] calculating user-independent tag usage count"      
      @cached_count ||= Tagging.count(:id,
                                      :conditions => ["tag_id = ?", self.id])
    end
    #logger.debug "[TAG:] count: #{@cached_count}" 
    @cached_count                                                                     
  end
  
  validates :name, :format => { :with => /^[^:?]*$/, :message => "no ? and : allowed!" } 
  validate :not_blacklisted

  protected
  def not_blacklisted
    blacklist = BlacklistTag.where("name = ?", name).first
    errors.add(:name, "The tag is blacklisted!") if blacklist 
  end
  
  
end

