class DriverUpdateController < PackageController

  before_filter :require_project
  before_filter :require_package


  def create
    @repositories = @project.each_repository.map{|repo| {:project => @project.name, :repo => repo.name, :archs => repo.each_arch.map{|arch| arch.to_s} } }
    @packages = []
  end


  def edit
    # load repos etc from services file
    @repositories = {}
    @packages = []
  end


  def save

  end

end
