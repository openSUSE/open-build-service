class Notifications::DailyEmailItem < Notifications::Base
  def self.cleanup
    raise NotImplementedError
  end
end
