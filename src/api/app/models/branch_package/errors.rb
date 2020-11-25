module BranchPackage::Errors
  class InvalidArgument < APIError; end

  class InvalidFilelistError < APIError; end

  class DoubleBranchPackageError < APIError
    attr_reader :project, :package

    def initialize(project, package)
      super(message)
      @project = project
      @package = package
    end
  end
end
