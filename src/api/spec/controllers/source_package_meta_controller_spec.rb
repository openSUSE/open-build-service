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
end
