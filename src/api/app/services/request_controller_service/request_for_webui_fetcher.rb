module RequestControllerService
  class RequestForWebuiFetcher
    def self.call(bs_request, diff_limit, diff_to_superseded, current_user)
      RequestWebuiInfo.new(bs_request, diff_limit: diff_limit, current_user: current_user, diff_to_superseded: diff_to_superseded)
    end
  end
end
