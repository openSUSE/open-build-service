RSpec.describe BsRequestActionDescriptionComponent, type: :component do
  context 'add_role' do
    before do
      create(:add_maintainer_request)
    end

    it 'renders the "add_role" preview' do
      render_preview('add_role')

      expect(rendered_content).to have_text('get the role')
    end
  end

  context 'change_devel' do
    before do
      create(:bs_request_with_change_devel_action)
    end

    it 'renders the "change_devel" previews' do
      %i[change_devel change_devel_text_only].each do |preview_name|
        render_preview(preview_name)

        expect(rendered_content).to have_text('be devel project/package of')
      end
    end
  end

  context 'delete' do
    before do
      create(:bs_request_action_delete, target_project: create(:project), bs_request: create(:delete_bs_request))
    end

    it 'renders the "delete" previews' do
      %i[delete delete_text_only].each do |preview_name|
        render_preview(preview_name)

        expect(rendered_content).to have_text('Delete')
      end
    end
  end

  context 'maintenance_incident' do
    before do
      create(:bs_request_with_maintenance_incident_actions)
    end

    it 'renders the "maintenance_incident" preview' do
      render_preview('maintenance_incident_text_only')

      expect(rendered_content).to have_text('Submit update from')
    end
  end

  context 'maintenance_release' do
    before do
      create(:bs_request_with_maintenance_release_actions)
    end

    it 'renders the "maintenance_release" preview' do
      render_preview('maintenance_release_text_only')

      expect(rendered_content).to have_text('Maintenance release')
    end
  end

  context 'set_bugowner' do
    before do
      create(:set_bugowner_request)
    end

    it 'renders the "set_bugowner" preview' do
      render_preview('set_bugowner_text_only')

      expect(rendered_content).to have_text('become bugowner')
    end
  end

  context 'submit' do
    before do
      create(:bs_request_with_submit_action)
    end

    it 'renders the "submit" previews' do
      %i[submit submit_text_only].each do |preview_name|
        render_preview(preview_name)

        expect(rendered_content).to have_text('Submit')
      end
    end
  end
end
