module Token::Errors
  extend ActiveSupport::Concern

  class NoReleaseTargetFound < APIError
    setup 404
  end

  class NonExistentWorkflowsFile < APIError
    setup 404
  end
end
