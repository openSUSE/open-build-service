
class CopyProjectJob < Struct.new(:project, :params)

  def perform
    c = SourceController.new
    c.copy_project(project, params)
  end

end

