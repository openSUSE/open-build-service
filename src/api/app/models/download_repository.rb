class DownloadRepository < ApplicationRecord
  REPOTYPES = %w[rpmmd susetags deb arch mdk registry apk].freeze

  belongs_to :repository

  validates :arch, uniqueness: { scope: :repository_id, case_sensitive: false }, presence: true
  validate :architecture_inclusion
  validates :url, presence: true, format: { with: /\A[a-zA-Z]+:.*\Z/ } # from backend/BSVerify.pm
  validates :repotype, presence: true
  validates :repotype, inclusion: { in: REPOTYPES, message: "'%{value}' is not a valid repotype" }

  delegate :to_s, to: :id

  private

  def architecture_inclusion
    # Workaround for rspec validation test (validate_presence_of(:repository_id))
    return unless repository
    return if repository.architectures.pluck(:name).include?(arch)

    errors.add(:base, 'Architecture has to be available via repository association')
  end
end

# == Schema Information
#
# Table name: download_repositories
#
#  id                   :integer          not null, primary key
#  arch                 :string(255)      not null
#  archfilter           :string(255)
#  mastersslfingerprint :string(255)
#  masterurl            :string(255)
#  pubkey               :text(65535)
#  repotype             :string(255)
#  url                  :string(255)      not null
#  repository_id        :integer          not null, indexed
#
# Indexes
#
#  repository_id  (repository_id)
#
# Foreign Keys
#
#  download_repositories_ibfk_1  (repository_id => repositories.id)
#
