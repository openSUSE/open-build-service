class ChannelBinaryList < ActiveRecord::Base

  belongs_to :channel
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture
  has_many :channel_binaries, dependent: :destroy

end
