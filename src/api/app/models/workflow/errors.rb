module Workflow::Errors
  extend ActiveSupport::Concern

  class UnsupportedWorkflowFilters < APIError
    setup 422
  end

  class UnsupportedWorkflowFilterTypes < APIError
    setup 422
  end
end
