require 'rails_helper'

RSpec.describe SourceProjectController, vcr: true do
  render_views
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project_with_package) do
    create(:project_with_package, package_name: 'foo', maintainer: user)
  end

  describe '#show' do
    before do
      login user
      get :show, params: { project: project_with_package.name, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }
    it 'has one project named foo' do
      assert_select 'directory[count=1]' do
        assert_select "[name='foo']"
      end
    end
  end

  describe '#delete' do
    context 'without login' do
      before do
        delete :delete, params: { project: project_with_package.name, format: :xml }
      end

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'without permission' do
      let(:another_user) { create(:confirmed_user) }

      before do
        login another_user
        delete :delete, params: { project: project_with_package.name, format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'with permissions' do
      before do
        login user
        delete :delete, params: { project: project_with_package.name, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end
  end
end
