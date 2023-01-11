class ProjectServiceFile < ProjectFile
  def initialize(attributes = {})
    super
    @name = '_service'
  end

  # You dont want to change name of _service
  private :name=
end
