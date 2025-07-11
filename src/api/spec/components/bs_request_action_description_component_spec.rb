RSpec.describe BsRequestActionDescriptionComponent, type: :component do
  it 'renders the "add_role" preview' do
    render_preview('add_role')

    expect(rendered_content).to have_text('get the role')
  end

  it 'renders the "change_devel" previews' do
    %i[change_devel change_devel_text_only].each do |preview_name|
      render_preview(preview_name)

      expect(rendered_content).to have_text('be devel project/package of')
    end
  end
end
