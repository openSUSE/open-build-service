module Package::Errors
  extend ActiveSupport::Concern

  class PackageError < StandardError; end

  class CycleError < APIError
    setup 'cycle_error'
  end

  class DeleteError < APIError
    attr_accessor :packages
    setup 'delete_error'
  end

  class SaveError < APIError
    setup 'package_save_error'
  end

  class WritePermissionError < APIError
    setup 'package_write_permission_error'
  end

  class UnknownObjectError < APIError
    setup 'unknown_package', 404, 'Unknown package'
  end

  class ReadAccessError < UnknownObjectError; end

  class ReadSourceAccessError < APIError
    setup 'source_access_no_permission', 403, 'Source Access not allowed'
  end

  class IllegalFileName < APIError; setup 'invalid_file_name_error'; end

  class PutFileNoPermission < APIError; setup 403; end
end
