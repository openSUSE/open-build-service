class AbstractMethodCalled < APIError
  setup 'not_implemented', 501, 'Called unimplemented abstract method'
end
