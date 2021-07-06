module Token::Errors
  extend ActiveSupport::Concern

  class UnallowedEventAndAction < APIError
    setup 422
  end

  class NoReleaseTargetFound < APIError
    setup 404
  end

  class NonExistentWorkflowsFile < APIError
    setup 404
  end

  class SCMTokenInvalid < APIError
    setup 401
  end

  class WorkflowsYamlNotParsable < APIError
    setup 400
  end

  class InvalidWorkflowStepDefinition < APIError
    setup 403
  end

  class CanNotBranchPackage < APIError
    setup 422
  end

  class CanNotBranchPackageNoPermission < APIError
    setup 403
  end

  class CanNotBranchPackageNotFound < APIError
    setup 404
  end
end
