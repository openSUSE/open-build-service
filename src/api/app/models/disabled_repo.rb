class DisabledRepo < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :repository
  belongs_to :architecture
end
