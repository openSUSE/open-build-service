module BranchPackage::Errors
  class InvalidArgument < APIError; end

  class InvalidFilelistError < APIError; end

  class CanNotBranchPackage < APIError
    setup 422
  end

  class CanNotBranchPackageNoPermission < APIError
    setup 403
  end

  class BranchRejected < APIError
    setup 403
  end

  class CanNotBranchPackageNotFound < APIError
    setup 404
  end

  class DoubleBranchPackageError < APIError
    attr_reader :project, :package

    def initialize(project, package)
      super(message)
      @project = project
      @package = package
    end
  end
end
