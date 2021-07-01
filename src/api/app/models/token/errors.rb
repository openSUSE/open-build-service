module Token::Errors
  extend ActiveSupport::Concern

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
end
