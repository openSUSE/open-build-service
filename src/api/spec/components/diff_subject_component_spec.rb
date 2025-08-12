RSpec.describe DiffSubjectComponent, type: :component do
  it 'renders the unmodified preview' do
    render_preview('not_modified')

    expect(rendered_content).to have_text('file.txt')
  end

  it 'renders the rest of the previews' do
    %i[added deleted changed renamed].each do |preview_name|
      render_preview(preview_name)

      expect(rendered_content).to have_text(preview_name.capitalize)
    end
  end

  context 'when the state is added' do
    it 'renders the new filename' do
      render_inline(described_class.new(state: 'added', new_filename: 'new_file.txt', old_filename: ''))
      expect(rendered_content).to have_text('new_file.txt')
    end
  end

  context 'when the state is deleted' do
    it 'renders the new filename' do
      render_inline(described_class.new(state: 'deleted', new_filename: 'new_file.txt', old_filename: ''))
      expect(rendered_content).to have_text('new_file.txt')
    end
  end

  context 'when the state is changed' do
    it 'renders the new filename' do
      render_inline(described_class.new(state: 'changed', new_filename: 'new_file.txt', old_filename: 'new_file.txt'))
      expect(rendered_content).to have_text('new_file.txt')
    end
  end

  context 'when the state is renamed' do
    it 'renders the new filename' do
      render_inline(described_class.new(state: 'renamed', new_filename: 'new_file.txt', old_filename: 'old_file.txt'))
      expect(rendered_content).to have_text('old_file.txt')
    end
  end

  context 'when the state is blank' do
    it 'renders the new filename' do
      render_inline(described_class.new(state: '', new_filename: 'new_file.txt', old_filename: ''))
      expect(rendered_content).to have_text('new_file.txt')
    end
  end
end
