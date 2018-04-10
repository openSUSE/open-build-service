# frozen_string_literal: true

# TODO: why not use habtm?
class WatchedProject < ApplicationRecord
  belongs_to :user, inverse_of: :watched_projects
  belongs_to :project, inverse_of: :watched_projects

  validates :project, presence: true
  validates :user, presence: true
end

# == Schema Information
#
# Table name: watched_projects
#
#  id         :integer          not null, primary key
#  user_id    :integer          default(0), not null, indexed
#  project_id :integer          not null
#
# Indexes
#
#  watched_projects_users_fk_1  (user_id)
#
# Foreign Keys
#
#  watched_projects_ibfk_1  (user_id => users.id)
#
