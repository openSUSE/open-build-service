# frozen_string_literal: true

class DiffListComponent < ApplicationComponent
  attr_reader :diff_list, :view_id, :commentable, :commented_lines, :source_package, :target_package, :source_rev, :target_rev

  def initialize(diff_list:, view_id: nil, commentable: nil, commented_lines: {}, source_package: nil, target_package: nil, source_rev: nil, target_rev: nil)
    super
    @diff_list = diff_list
    @view_id = view_id
    @commentable = commentable
    @commented_lines = commented_lines
    @source_package = source_package
    @target_package = target_package
    @source_rev = source_rev
    @target_rev = target_rev
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

    commented_lines.key?(file_index)
  end

  def source_file(filename)
    return nil unless @source_package
    return nil unless @source_package.file_exists?(filename, { rev: @source_rev, expand: 1 }.compact)

    project_package_file_path(@source_package.project, @source_package, filename, rev: @source_rev, expand: 1)
  end

  def target_file(filename)
    return nil unless @target_package
    return nil unless @target_package.file_exists?(filename, { rev: @target_rev, expand: 1 }.compact)

    project_package_file_path(@target_package.project, @target_package, filename, rev: @target_rev, expand: 1)
  end
end
