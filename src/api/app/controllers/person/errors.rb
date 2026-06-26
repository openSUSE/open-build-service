module Person::Errors
  class NotFoundError < APIError
    setup 'not_found', 404, 'Make sure you are in the beta program'
  end

  class FilterNotSupportedError < APIError
    setup 'bad_request', 400, 'Filter not supported'
  end
end
