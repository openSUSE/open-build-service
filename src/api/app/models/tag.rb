class Tag < ActiveRecord::Base
  
  has_many :taggings, :dependent => :destroy
  has_many :db_projects, :through => :taggings,
                          :conditions => "taggings.taggable_type = 'DbProject'"
  has_many :db_packages, :through => :taggings,
                          :conditions => "taggings.taggable_type = 'DbPackage'"
  
  has_many :users, :through => :taggings
  
  def before_save
  end

   def weight
    @cached_weight ||= Tagging.count(:all,
                  :conditions => ["tag_id = ?", self.id])     
   @cached_weight
   end 
                  
end

