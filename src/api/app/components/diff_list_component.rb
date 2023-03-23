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

  def expand?(filename, state)
    state != 'deleted' && filename.exclude?('/') && (filename == '_patchinfo' || filename.ends_with?('.spec', '.changes'))
  end
end
