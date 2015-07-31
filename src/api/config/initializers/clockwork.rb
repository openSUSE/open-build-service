module Clockwork
  configure do |config|
    error_handler do |error|
      HoptoadNotifier.notify(error)
    end
  end
end
