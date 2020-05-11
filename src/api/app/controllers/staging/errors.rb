module Staging::Errors
  extend ActiveSupport::Concern

  class StagingProjectNotAcceptable < APIError; end

  class StagingWorkflowNotFound < APIError
    setup 404
  end

  class StagingProjectNotFound < APIError
    setup 404
  end
end
