class Download < ActiveRecord::Base
  belongs_to :project
  belongs_to :architecture

  attr_accessible nil
end
