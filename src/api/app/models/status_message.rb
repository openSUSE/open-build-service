class StatusMessage < ActiveRecord::Base

  belongs_to :user

  scope :alive, -> { where(:deleted_at => nil) }

  def delete
    self.deleted_at = Time.now
    self.save
  end

end
