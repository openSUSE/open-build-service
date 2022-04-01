module Workflow::Step::Errors
  extend ActiveSupport::Concern

  class NoSourceServiceDefined < APIError
    setup 404
  end
end
