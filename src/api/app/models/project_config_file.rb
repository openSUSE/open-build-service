class ProjectConfigFile < ProjectFile

  def initialize(attributes = {})
    super
    @name = '_config'
  end

  # calculates the real url on the backend to search the file
  def full_path(params = {})
    query = params.blank? ? '' : "?#{params.to_query}"
    URI.encode("/source/#{project_name}/#{name}") + query
  end

  # You dont want to change name of _config
  private :name=

end
