class DownloadRepository < ApplicationRecord
  REPOTYPES = ["rpmmd", "susetags", "deb", "arch", "mdk"]

  belongs_to :repository

  validates :repository_id, presence: true
  validates :arch, uniqueness: { scope: :repository_id }, presence: true
  validate :architecture_inclusion
  validates :url, presence: true, format: { with: /\A[a-zA-Z]+:.*\Z/ } # from backend/BSVerify.pm
  validates :repotype, presence: true
  validates :repotype, inclusion: { in: REPOTYPES }

  delegate :to_s, to: :id

  def architecture_inclusion
    # Workaround for rspec validation test (validate_presence_of(:repository_id))
    return unless repository
    return if repository.architectures.pluck(:name).include?(arch)

    errors.add(:base, "Architecture has to be available via repository association.")
  end
end
