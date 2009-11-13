# Exception class for BackgrounDRb connection errors
module BackgrounDRb
  # raised when connection to a particular server failed
  class BdrbConnError < RuntimeError
    attr_accessor :message
    def initialize(message)
      @message = message
    end
  end
  # raised when connection to all of the available servers failed
  class NoServerAvailable < RuntimeError
    attr_accessor :message
    def initialize(message)
      @message = message
    end
  end

  # raised, when said task was submitted without a job key, whereas
  # nature of the task requires a job key
  class NoJobKey < RuntimeError; end

  # raised if worker throws some error
  class RemoteWorkerError < RuntimeError
    attr_accessor :message
    def initialize message
      @message = message
    end
  end
end
