class DriverUpdateController < PackageController

  before_filter :require_project
  before_filter :require_package


  def create
    @repositories = @project.each_repository.map{|repo| {:project => @project.name, :repo => repo.name, :archs => repo.each_arch.map{|arch| arch.to_s} } }
    @packages = find_cached(Package, :all, :project => @project.name, :expires_in => 30.seconds ).each_entry.map{|package| {:name => package.name}}[0..50]
  end


  def edit
    # load repos etc from services file
    @repositories = {}
    @packages = {}
  end


  def save
    flash[:warn] = "Saving of DUD kiwi configs is not yet implemented"
    redirect_to :controller => :package, :action => :show, :project => @project, :package => @package
  end

end
