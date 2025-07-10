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
end
