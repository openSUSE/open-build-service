class Decorators::Notification::Common
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def description_text
    raise NotImplementedError, self
  end

  def notifiable_link_text(helpers)
    raise NotImplementedError, self
  end

  def notifiable_link_path
    raise NotImplementedError, self
  end

  def avatar_objects
    raise NotImplementedError, self
  end
end
