
class CopyProjectJob < Struct.new(:project, :params)

  def perform
    c = SourceController.new
    c.do_project_copy(project, params)
  end

end

