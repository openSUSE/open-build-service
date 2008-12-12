class Download < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :architecture
end
