class StatusMessage < ActiveRecord::Base


  belongs_to :user


  def delete
    self.deleted_at = Time.now
    self.save
  end


  def is_deleted?
    true if not self.deleted_at.nil?
  end


end
