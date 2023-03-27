# frozen_string_literal: true

class DiffListComponent < ApplicationComponent
  attr_reader :diff_list, :view_id, :commentable, :commented_lines

  def initialize(diff_list:, view_id: nil, commentable: nil)
    super
    @diff_list = diff_list
    @view_id = view_id
    @commentable = commentable
    @commented_lines = commentable ? commentable.comments.where.not(diff_ref: nil).select(:diff_ref).distinct.pluck(:diff_ref) : []
  end

  # We expand the diff if the changeset:
  # it's not for a deletion
  # and it is not a directory
  # and it's a _patchinfo, *.spec or *.changes file
  # or someone commented on the diff
  def expand?(filename, state, file_index)
    return true if
      state != 'deleted' &&
      filename.exclude?('/') &&
      (filename == '_patchinfo' || filename.ends_with?('.spec', '.changes'))

    commented_lines.any? { |cl| cl.split('_')[1].to_i == file_index }
  end
end
