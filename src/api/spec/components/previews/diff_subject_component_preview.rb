class DiffSubjectComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/diff_subject_component/
  def added
    render(DiffSubjectComponent.new(state: 'added', file_info: { 'new' => { 'name' => 'new_file.txt' } }))
  end

  def deleted
    render(DiffSubjectComponent.new(state: 'deleted', file_info: { 'new' => { 'name' => 'new_file.txt' } }))
  end

  def changed
    render(DiffSubjectComponent.new(state: 'changed', file_info: { 'new' => { 'name' => 'file.txt' } }))
  end

  def renamed
    render(DiffSubjectComponent.new(state: 'renamed', file_info: { 'new' => { 'name' => 'file.txt' } }))
  end

  def not_modified
    render(DiffSubjectComponent.new(state: '', file_info: { 'new' => { 'name' => 'file.txt' } }))
  end
end
