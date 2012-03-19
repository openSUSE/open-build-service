
class CopyProjectJob

  def perform(project, params)
    c = SourceController.new
    c.do_project_copy(project, params)
  end

end

