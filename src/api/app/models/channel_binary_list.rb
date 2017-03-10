class ChannelBinaryList < ApplicationRecord
  belongs_to :channel
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture
  has_many :channel_binaries, dependent: :delete_all

  def self._sync_keys
    [:project, :repository, :architecture]
  end
end

# == Schema Information
#
# Table name: channel_binary_lists
#
#  id              :integer          not null, primary key
#  channel_id      :integer          not null
#  project_id      :integer
#  repository_id   :integer
#  architecture_id :integer
#
# Indexes
#
#  architecture_id  (architecture_id)
#  channel_id       (channel_id)
#  project_id       (project_id)
#  repository_id    (repository_id)
#
