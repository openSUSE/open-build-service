class DownloadRepository < ActiveRecord::Base
  belongs_to :repository

  validates :repository, presence: true
  validates :arch, presence: true
  validates :url, presence: true
  validates :repotype, presence: true

# def self._sync_keys
#   [ :arch, :url ]
# end

end
