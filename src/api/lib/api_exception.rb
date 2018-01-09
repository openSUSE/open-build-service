
class APIException < RuntimeError
  def self.abstract_class?
    true
  end

  class << self
    @errorcode = nil
    @status = 400
    @default_message = nil

    def setup(setvalue, status = nil, message = nil)
      if setvalue.is_a? String
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
    err = self.class.instance_variable_get '@errorcode'
    return err if err
    err = self.class.name.demodulize.underscore
    # if the class name stops with Error, strip that
    err.gsub(%r{_error$}, '')
  end

  def status
    self.class.instance_variable_get '@status'
  end

  def default_message
    self.class.instance_variable_get '@default_message'
  end
end

# 403 errors (how about a subclass?)
class NoPermission < APIException
  setup 403
end
class CreateProjectNoPermission < APIException
  setup 403
end
class DeleteFileNoPermission < APIException
  setup 403
end
class PostRequestNoPermission < APIException
  setup 403
end
class OpenReleaseRequest < APIException
  setup 403
end

# 404 errors
class NotFoundError < APIException
  setup 404
end
class UnknownPackage < APIException
  setup 404
end
class UnknownRepository < APIException
  setup 404
end
class RepositoryMissing < APIException
  setup 404
end

# 400 errors
class MissingParameterError < APIException; end
class RemoteProjectError < APIException; end
class InvalidParameterError < APIException; end
class InvalidProjectNameError < APIException; end
class UnknownCommandError < APIException; end
class NotMissingError < APIException; end
class PackageAlreadyExists < APIException; end
class ExpandError < APIException;
  setup 'expand_error'
end
class ProjectNotLocked < APIException
  setup 'not_locked'
end
