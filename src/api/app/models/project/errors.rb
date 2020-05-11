module Project::Errors
  extend ActiveSupport::Concern

  class CycleError < APIError
    setup 'project_cycle'
  end

  class DeleteError < APIError
    setup 'delete_error'
  end

  # unknown objects and no read access permission are handled in the same way by default
  class UnknownObjectError < APIError
    setup 'unknown_project', 404, 'Unknown project'
  end

  class ReadAccessError < UnknownObjectError; end

  class SaveError < APIError
    setup 'project_save_error'
  end

  class WritePermissionError < APIError
    setup 'project_write_permission_error'
  end

  class ForbiddenError < APIError
    setup('change_project_protection_level', 403,
          "admin rights are required to raise the protection level of a project (it won't be safe anyway)")
  end
end
