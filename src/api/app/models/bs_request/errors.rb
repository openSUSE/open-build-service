module BsRequest::Errors
  extend ActiveSupport::Concern

  class InvalidStateError < APIError
    setup 'request_not_modifiable', 404
  end
  class InvalidReview < APIError
    setup 'invalid_review', 400, 'request review item is not specified via by_user, by_group or by_project'
  end
  class InvalidDate < APIError
    setup 'invalid_date', 400
  end
  class UnderEmbargo < APIError
    setup 'under_embargo', 400
  end
  class SaveError < APIError
    setup 'request_save_error'
  end
end
