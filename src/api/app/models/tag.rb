class Tag < ActiveRecord::Base
  
  has_many :taggings, :dependent => :destroy
  has_many :db_projects, :through => :taggings,
    :conditions => "taggings.taggable_type = 'DbProject'"
  has_many :db_packages, :through => :taggings,
    :conditions => "taggings.taggable_type = 'DbPackage'"
  
  has_many :users, :through => :taggings
  
  def before_save
  end
  
  def weight(opt={})
    opt ||= {:scope => "global"}
    if opt[:scope] == "user" 
      user = opt[:user]
      @cached_weight ||= Tagging.count(:all,
                                       :conditions => ["tag_id = ? AND user_id = ?", self.id, user.id])     
      
    else
      @cached_weight ||= Tagging.count(:all,
                                       :conditions => ["tag_id = ?", self.id])     
    end
    @cached_weight
  end 
  
end

