class WatchedProject < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'bs_user_id'

  attr_accessible :name
end
