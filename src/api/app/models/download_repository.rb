class DownloadRepository < ActiveRecord::Base
  belongs_to :repository

  validates :repository_id, presence: true
  validates :arch, uniqueness: { scope: :repository_id}, presence: true
  validates :url, presence: true
  validates :repotype, presence: true

  REPOTYPES = ["rpmmd", "susetags", "deb", "arch", "mdk"]

  delegate :to_s, to: :id
end
