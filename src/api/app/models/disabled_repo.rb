class DisabledRepo < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :repository
  belongs_to :architecture

# don't allow NULL values in the sql database, unique indices don't work with them
def before_save
  self.repository_id = 0 if self.repository_id == nil
  self.architecture_id = 0 if self.architecture_id == nil
end

def after_load
  self.repository_id = nil if self.repository_id == 0
  self.repository_id = nil if self.repository_id == 0
end
end
