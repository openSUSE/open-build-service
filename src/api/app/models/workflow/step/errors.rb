module Workflow::Step::Errors
  class NoSourceServiceDefined < APIError
    setup 404
  end
end
