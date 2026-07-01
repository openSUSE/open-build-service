RSpec.describe SourcePackageMetaController, :vcr do
  render_views
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project_with_package) do
    create(:project_with_package, package_name: 'foo', maintainer: user)
  end

  describe 'GET #show' do
    context 'package exist' do
      before do
        login user
        project_with_package
        get :show, params: { project: project_with_package.name,
                             package: 'foo', format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'package do not exist' do
      before do
        login user
        project_with_package
        get :show, params: { project: project_with_package.name,
                             package: 'bar', format: :xml }
      end

      it { expect(response).not_to have_http_status(:success) }
    end

    context 'package description does not include escaped carriage return characters' do
      before do
        login user
        project_with_package.packages.first.update(description: "%description\r\nctris is a colorized, small and flexible Tetris(TM)-clone for the console.")
        project_with_package
        get :show, params: { project: project_with_package.name,
                             package: 'foo', format: :xml }
      end

      it { expect(response.body).not_to include('&#13;') }
    end
  end

  describe 'PUT #update' do
    context 'well-formated XML' do
      let(:meta) do
        <<~META
          <package name="foo" project="#{project_with_package.name}">
            <title>My cool package</title>
            <description/>
          </package>
        META
      end

      before do
        login user
        project_with_package
        put :update, params: { project: project_with_package,
                               package: 'foo' },
                     body: meta, format: :xml
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'bad XML' do
      let(:meta) { "package name=\"foo\" project=\"#{project_with_package.name}\"</package>" }

      before do
        login user
        project_with_package
        put :update, params: { project: project_with_package,
                               package: 'foo' },
                     body: meta, format: :xml
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(Xmlhash.parse(response.body)['code']).to eq('validation_failed') }
    end

    context 'inherited package' do
      let(:package_name) { 'foo' }
      let(:linked_project) { create(:project_with_package, package_name: package_name) }
      let(:local_project) { create(:project, maintainer: user) }
      let!(:link_association) { create(:linked_project, project: local_project, linked_db_project: linked_project) }

      context 'with well-formated XML' do
        let(:meta) do
          <<~META
            <package name="#{package_name}" project="#{local_project.name}">
              <title>My inherited package</title>
              <description/>
            </package>
          META
        end

        before do
          login user
          link_association
          put :update, params: { project: local_project,
                                 package: package_name },
                       body: meta, format: :xml
        end

        it { expect(response).to have_http_status(:success) }

        it 'creates a local package' do
          expect(local_project.packages.exists?(name: package_name)).to be(true)
        end
      end

      context 'with invalid XML' do
        let(:meta) { '<title/>' }

        before do
          login user
          link_association
          put :update, params: { project: local_project,
                                 package: package_name },
                       body: meta, format: :xml
        end

        it { expect(response).to have_http_status(:bad_request) }
        it { expect(Xmlhash.parse(response.body)['code']).to eq('validation_failed') }
      end

      # The inherited-package branch builds a non-persisted package and saves it.
      # When that save aborts, Rails raises ActiveRecord::RecordNotSaved, which is
      # not mapped to a client error globally and previously surfaced as a 500
      # (#19529). The controller now maps it to a 400, matching the existing
      # (persisted) package path.
      context 'when saving the new package raises ActiveRecord::RecordNotSaved' do
        let(:meta) do
          <<~META
            <package name="#{package_name}" project="#{local_project.name}">
              <title>My inherited package</title>
              <description/>
            </package>
          META
        end

        before do
          login user
          link_association
          allow_any_instance_of(Package).to receive(:update_from_xml).and_raise(ActiveRecord::RecordNotSaved.new('Failed to save the record'))
          put :update, params: { project: local_project,
                                 package: package_name },
                       body: meta, format: :xml
        end

        it { expect(response).to have_http_status(:bad_request) }
        it { expect(Xmlhash.parse(response.body)['code']).to eq('invalid_record') }
      end

      context 'without permission to update the local project' do
        let(:other_user) { create(:confirmed_user, login: 'jerry') }
        let(:local_project) { create(:project, maintainer: other_user) }
        let(:meta) do
          <<~META
            <package name="#{package_name}" project="#{local_project.name}">
              <title>My inherited package</title>
              <description/>
            </package>
          META
        end

        before do
          login user
          link_association
          put :update, params: { project: local_project,
                                 package: package_name },
                       body: meta, format: :xml
        end

        it { expect(response).to have_http_status(:forbidden) }

        it 'does not create a local package' do
          expect(local_project.packages.exists?(name: package_name)).to be(false)
        end
      end
    end
  end
end
