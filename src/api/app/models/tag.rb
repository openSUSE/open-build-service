class Tag < ActiveRecord::Base
  
  has_many :taggings, :dependent => :destroy
  has_many :db_projects, :through => :taggings,
    :conditions => "taggings.taggable_type = 'DbProject'"
  has_many :db_packages, :through => :taggings,
    :conditions => "taggings.taggable_type = 'DbPackage'"
  
  has_many :users, :through => :taggings
  
  def before_save
  end
  
  def count(opt={})
    
    if @cached_count 
        logger.debug "[TAG:] tag usage count is already calculated. count: #{@cached_count}"
      return @cached_count
    end
    
    if opt[:scope] == "user"
      user = opt[:user]
      logger.debug "[TAG:] calculating user-dependent tag usage count"
      @cached_count ||= Tagging.count(:all,
                                       :conditions => ["tag_id = ? AND user_id = ?", self.id, user.id])
    else
      logger.debug "[TAG:] calculating user-independent tag usage count"      
      @cached_count ||= Tagging.count(:all,
                                      :conditions => ["tag_id = ?", self.id])
    end
    logger.debug "[TAG:] count: #{@cached_count}" 
    @cached_count                                                                     
  end
  
  
#  def find_by_user(userid)
#    find_all(:condition => [])
#  end
  
end

