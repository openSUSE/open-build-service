class DiffSubjectComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/diff_subject_component/preview
  def preview
    render(DiffSubjectComponent.new(state: 'changed', new_filename: 'a_file_name', old_filename: 'old_filah'))
  end
end
