
class APIError < RuntimeError
  def self.abstract_class?
    true
  end

  class << self
    @errorcode = nil
    @status = 400
    @default_message = nil

    def setup(setvalue, status = nil, message = nil)
      if setvalue.is_a?(String)
        @errorcode = setvalue
        @status = status || 400
        @default_message = message
      else # support having the status first
        @status = setvalue
        @default_message = status
      end
    end
  end

  def errorcode
    err = self.class.instance_variable_get('@errorcode')
    return err if err
    err = self.class.name.demodulize.underscore
    # if the class name stops with Error, strip that
    err.gsub(%r{_error$}, '')
  end

  def status
    self.class.instance_variable_get('@status')
  end

  def default_message
    self.class.instance_variable_get('@default_message')
  end
end

# 403 errors (how about a subclass?)
class NoPermission < APIError
  setup 403
end
class CreateProjectNoPermission < APIError
  setup 403
end
class DeleteFileNoPermission < APIError
  setup 403
end
class PostRequestNoPermission < APIError
  setup 403
end
class OpenReleaseRequest < APIError
  setup 403
end

# 404 errors
class NotFoundError < APIError
  setup 404
end
class UnknownPackage < APIError
  setup 404
end
class UnknownRepository < APIError
  setup 404
end
class RepositoryMissing < APIError
  setup 404
end

# 400 errors
class MissingParameterError < APIError; end
class RemoteProjectError < APIError; end
class InvalidParameterError < APIError; end
class InvalidProjectNameError < APIError; end
class UnknownCommandError < APIError; end
class NotMissingError < APIError; end
class PackageAlreadyExists < APIError; end
class ExpandError < APIError
  setup 'expand_error'
end
class ProjectNotLocked < APIError
  setup 'not_locked'
end
