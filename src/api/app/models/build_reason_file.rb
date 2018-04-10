# frozen_string_literal: true

# Backend::File model to represent files that belongs to the project in the backend
# Special files that are stored in /source/project/ folder
#   _project/_meta (using meta=1 in the query),
#   _project/_pubkey (just for read and delete),
#   _history (readonly),
#   _config
class BuildReasonFile < Backend::File
  attr_accessor :project_name, :package_name, :repo, :arch

  validates :project_name, :package_name, :repo, :arch, presence: true

  def initialize(attributes = {})
    super
    @name = '_reason'
  end

  def full_path(query = {})
    URI.encode("/build/#{project_name}/#{repo}/#{arch}/#{package_name}/_reason") + "?#{query.to_query}"
  end
end
