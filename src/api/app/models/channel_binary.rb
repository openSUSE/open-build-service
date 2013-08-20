class ChannelBinary < ActiveRecord::Base

  belongs_to :channel_binary_list
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture

end
