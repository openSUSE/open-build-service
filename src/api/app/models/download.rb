class Download < ActiveRecord::Base
  belongs_to :project
  belongs_to :architecture
end
