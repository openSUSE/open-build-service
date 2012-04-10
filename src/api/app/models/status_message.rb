class StatusMessage < ActiveRecord::Base

  belongs_to :user

  scope :alive, where(:deleted_at => nil)

  attr_accessible :message, :user

  def delete
    self.deleted_at = Time.now
    self.save
  end

end
