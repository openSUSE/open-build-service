require 'rails_helper'

RSpec.describe SourceAttributeController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }
  let(:main_attribute) { create(:attrib, project: user.home_project) }
  let(:additional_attribute) { create(:attrib, project: user.home_project) }

  describe 'GET #show' do
    before do
      login user
      main_attribute
    end

    it 'returns both without filter' do
      additional_attribute
      get :show, params: { project: project }
      resp = Xmlhash.parse(response.body).elements('attribute')
      expect(resp).to match_array([{ 'namespace' => main_attribute.namespace, 'name' => main_attribute.name },
                                   { 'namespace' => additional_attribute.namespace, 'name' => additional_attribute.name }])
    end

    it 'filters only the specified attribute' do
      additional_attribute
      get :show, params: { project: project, attribute: main_attribute.fullname }
      resp = Xmlhash.parse(response.body)
      expect(resp.elements('attribute')).to contain_exactly('namespace' => main_attribute.namespace, 'name' => main_attribute.name)
    end
  end
end
