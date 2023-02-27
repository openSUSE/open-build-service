# frozen_string_literal: true

class DiffListComponent < ApplicationComponent
  attr_reader :diff_list, :view_id

  def initialize(diff_list:, view_id: nil)
    super
    @diff_list = diff_list
    @view_id = view_id
  end

  def badge_for_state(state)
    return 'text-bg-success' if state == 'added'
    return 'text-bg-danger' if state == 'deleted'

    'text-bg-info'
  end

  def changed_filename(old_filename, new_filename, state)
    return new_filename unless ['changed', 'renamed'].include?(state)
    return new_filename if old_filename == new_filename

    "#{old_filename} -> #{new_filename}"
  end

  def expand?(filename, state)
    state != 'deleted' && filename.exclude?('/') && (filename == '_patchinfo' || filename.ends_with?('.spec', '.changes'))
  end
end
