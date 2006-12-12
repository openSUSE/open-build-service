class Tag < ActiveRecord::Base
  #has_and_belongs_to_many :db_project
  
  has_many :taggings, :dependent => :destroy
  has_many :db_projects, :through => :taggings,
                          :conditions => "taggings.taggable_type = 'DbProject'"
  has_many :users, :through => :taggings
  
  def before_save
  end

end
