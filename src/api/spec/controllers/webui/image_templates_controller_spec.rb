require 'rails_helper'

RSpec.describe Webui::ImageTemplatesController, type: :controller do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }
  let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
  let!(:attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }
  let!(:tumbleweed_project) { create(:project, name: 'openSUSE_Tumbleweed') }

  it { is_expected.to use_before_action(:require_login) }

  describe 'GET #index' do
    before do
      login(user)
      get :index
    end

    it { expect(assigns(:projects)).to eq([leap_project]) }
    it { is_expected.to render_template("webui/image_templates/index") }
  end
end
