# frozen_string_literal: true
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
#  channel_id      :integer          not null, indexed
#  project_id      :integer          indexed
#  repository_id   :integer          indexed
#  architecture_id :integer          indexed
#
# Indexes
#
#  architecture_id  (architecture_id)
#  channel_id       (channel_id)
#  project_id       (project_id)
#  repository_id    (repository_id)
#
# Foreign Keys
#
#  channel_binary_lists_ibfk_1  (channel_id => channels.id)
#  channel_binary_lists_ibfk_2  (project_id => projects.id)
#  channel_binary_lists_ibfk_3  (repository_id => repositories.id)
#  channel_binary_lists_ibfk_4  (architecture_id => architectures.id)
#
