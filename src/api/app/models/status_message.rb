class StatusMessage < ApplicationRecord
  belongs_to :user
  validates :user, :severity, :message, presence: true
  scope :alive, -> { where(:deleted_at => nil).order("created_at DESC") }

  def delete
    self.deleted_at = Time.now
    self.save
  end
end
