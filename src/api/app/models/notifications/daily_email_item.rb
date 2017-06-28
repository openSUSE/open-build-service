class Notifications::DailyEmailItem < Notifications::Base
  def self.cleanup
    where(delivered: true).delete_all
  end
end
