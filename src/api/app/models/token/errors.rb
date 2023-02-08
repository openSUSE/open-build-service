require 'api_error'

module Token::Errors
  class NoReleaseTargetFound < APIError
    setup 404
  end

  class NonExistentRepository < APIError
    setup 404
  end

  class NonExistentWorkflowsFile < APIError
    setup 404
  end

  class MissingPayload < APIError
    setup 400
  end

  class SCMTokenInvalid < APIError
    setup 401
  end

  class WorkflowsYamlNotParsable < APIError
    setup 400
  end

  class WorkflowsYamlFormatError < APIError
    setup 400
  end
end
