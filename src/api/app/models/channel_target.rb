class ChannelTarget < ActiveRecord::Base

  belongs_to :channel
  belongs_to :repository

end
