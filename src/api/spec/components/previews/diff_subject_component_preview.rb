class DiffSubjectComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/diff_subject_component/
  def added
    render(DiffSubjectComponent.new(state: 'added', new_filename: 'new_file.txt', old_filename: ''))
  end

  def deleted
    render(DiffSubjectComponent.new(state: 'deleted', new_filename: 'file.txt', old_filename: 'file.txt'))
  end

  def changed
    render(DiffSubjectComponent.new(state: 'changed', new_filename: 'file.txt', old_filename: 'file.txt'))
  end

  def renamed
    render(DiffSubjectComponent.new(state: 'renamed', new_filename: 'new_file.txt', old_filename: 'old_file.txt'))
  end

  def not_modified
    render(DiffSubjectComponent.new(state: '', new_filename: 'file.txt', old_filename: 'file.txt'))
  end
end
