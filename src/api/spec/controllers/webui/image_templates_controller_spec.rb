require 'rails_helper'

RSpec.describe Webui::ImageTemplatesController, type: :controller do
  describe 'GET #index' do
    context 'without image templates' do
      before do
        get :index
      end

      it { is_expected.to render_template('webui/image_templates/index') }
      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:projects)).to eq([]) }
    end

    context 'with image templates' do
      let(:user) { create(:confirmed_user) }
      let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }
      let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
      let(:attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }
      let!(:tumbleweed_project) { create(:project, name: 'openSUSE_Tumbleweed') }

      before do
        login user
        attrib
        get :index
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:projects)).to eq([leap_project]) }
      it { is_expected.to render_template('webui/image_templates/index') }

      context 'and format XML' do
        before do
          get :index, format: :xml
        end

        it { is_expected.to render_template('webui/image_templates/index') }
      end
    end
  end
end
