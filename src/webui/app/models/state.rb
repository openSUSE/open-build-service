class State

  class << self
    def states
      Array[ "confirmed", "unconfirmed", "deleted", "locked"]
    end
  end

end
