require 'api_error'

module Token::Errors
  AUTHENTICATION_DOCUMENTATION_LINK = "#{::Workflow::SCM_CI_DOCUMENTATION_URL}#sec.obs.obs_scm_ci_workflow_integration.setup.token_authentication.how_to_authenticate_scm_with_obs".freeze

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
    setup 401, "Your SCM token secret is not properly set in your OBS workflow token.\nCheck #{AUTHENTICATION_DOCUMENTATION_LINK}"
  end

  class WorkflowsYamlNotParsable < APIError
    setup 400
  end

  class WorkflowsYamlFormatError < APIError
    setup 400
  end

  class InsufficientPermissionOnTargetRepository < APIError
    setup 403
  end
end
