# frozen_string_literal: true
# Backend::File model to represent files that belongs to the package in the backend
class PackageFile < Backend::File
  attr_accessor :project_name, :package_name

  validates :project_name, :package_name, presence: true

  # calculates the real url on the backend to search the file
  def full_path(query = {})
    URI.encode("/source/#{project_name}/#{package_name}/#{name}") + "?#{query.to_query}"
  end
end
