class DownloadRepository < ActiveRecord::Base
  REPOTYPES = ["rpmmd", "susetags", "deb", "arch", "mdk"]

  belongs_to :repository

  validates :repository_id, presence: true
  validates :arch, uniqueness: { scope: :repository_id}, presence: true
  validates :url, presence: true
  validates :repotype, presence: true
  validates :repotype, inclusion: { in: REPOTYPES }

  delegate :to_s, to: :id
end
