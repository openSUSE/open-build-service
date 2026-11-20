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
  end

  describe 'PUT #update of a new package' do
    context 'when a concurrent request creates the package first' do
      let(:meta) do
        <<~META
          <package name="bar" project="#{project_with_package.name}">
            <title>Title from the second request</title>
            <description/>
          </package>
        META
      end

      before do
        login user
        project_with_package
        allow(Package).to receive(:new).and_wrap_original do |original, *args, &block|
          package = original.call(*args, &block)
          if package.name == 'bar'
            allow(package).to receive(:update_from_xml) do
              create(:package, project: project_with_package, name: 'bar', title: 'Title from the first request')
              raise ActiveRecord::RecordNotUnique, "Duplicate entry for key 'packages_all_index'"
            end
          end
          package
        end

        put :update, params: { project: project_with_package, package: 'bar' }, body: meta, format: :xml
      end

      it 'updates the package created by the other request' do
        expect(response).to have_http_status(:success)
        expect(project_with_package.packages.find_by(name: 'bar').title).to eq('Title from the second request')
      end
    end
  end
end
