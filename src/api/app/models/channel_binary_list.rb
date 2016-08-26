class ChannelBinaryList < ApplicationRecord
  belongs_to :channel
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture
  has_many :channel_binaries, dependent: :delete_all

  def self._sync_keys
    [ :project, :repository, :architecture ]
  end
end
