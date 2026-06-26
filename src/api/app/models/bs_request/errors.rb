module BsRequest::Errors
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

  class AddReviewNotPermitted < APIError
    setup 403
  end

  class NotExistingTarget < APIError
    setup 404
  end

  class SourceChanged < APIError
  end

  class ReleaseTargetNoPermission < APIError
    setup 403
  end

  class ProjectLocked < APIError
    setup 403, 'The target project is locked'
  end

  class TargetNotMaintenance < APIError
    setup 404
  end

  class SourceMissing < APIError
    setup 'unknown_package', 404
  end

  class SetPriorityNoPermission < APIError
    setup 403
  end

  class ReviewChangeStateNoPermission < APIError
    setup 403
  end

  class ReviewNotSpecified < APIError
  end

  class ConflictingActions < APIError
  end

  class CreatorCannotAcceptOwnRequests < APIError
    setup 403, "the creator of the request cannot approve it's own requests"
  end
end
