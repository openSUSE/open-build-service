class StatusMessage < ActiveRecord::Base

  belongs_to :user

  def delete
    self.deleted_at = Time.now
    self.save
  end

end
