# frozen_string_literal: true

# Backend::File model to represent files that belongs to the project in the backend
# Special files that are stored in /source/project/ folder
#   _project/_meta (using meta=1 in the query),
#   _project/_pubkey (just for read and delete),
#   _history (readonly),
#   _config
class ProjectFile < Backend::File
  attr_accessor :project_name

  validates :project_name, presence: true

  # calculates the real url on the backend to search the file
  def full_path(query = {})
    URI.encode("/source/#{project_name}/_project/#{name}") + "?#{query.to_query}"
  end
end
