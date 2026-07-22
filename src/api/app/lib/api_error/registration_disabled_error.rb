class RegistrationDisabledError < APIError
  setup 403, 'Sign up is disabled'
end

