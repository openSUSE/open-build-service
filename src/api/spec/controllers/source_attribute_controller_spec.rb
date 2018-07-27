require 'rails_helper'

# CONFIG['global_write_through'] = true

RSpec.describe SourceAttributeController, vcr: true do
  render_views

  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }
  let(:update_project) { create(:project) }
  let(:main_attribute) { create(:attrib, project: user.home_project) }
  let(:additional_attribute) { create(:attrib, project: user.home_project) }
  let(:update_project_attrib) { create(:update_project_attrib, project: user.home_project, update_project: update_project) }

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

  describe 'PUT #update' do
    let(:xml_attrib) do
      <<~XMLATTRIB
        <attributes>
          <attribute namespace='#{update_project_attrib.namespace}' name='#{update_project_attrib.name}'>
            <value>1111112</value>
          </attribute>
        </attributes>
      XMLATTRIB
    end

    context 'update a valid attribute' do
      before do
        login user
        update_project_attrib
        put :update, params: { project: project,
                               attribute: update_project_attrib.fullname,
                               format: :xml },
                     body: xml_attrib
      end

      it { expect(response).to be_success }
    end

    context 'update invalid attribute' do
      let(:wrong_xml_attrib) do
        <<-XMLATTRIB
        <attributes>
          <attribute namespace='#{update_project_attrib.namespace}' name='#{additional_attribute.name}'>
            <value>1111112</value>
          </attribute>
        </attributes>
        XMLATTRIB
      end

      before do
        login user
        update_project_attrib
        put :update, params: { project: project,
                               attribute: update_project_attrib.fullname,
                               format: :xml },
                     body: wrong_xml_attrib
      end

      it { expect(response).not_to be_success }
      it 'gives the right status code' do
        resp = Xmlhash.parse(response.body)
        expect(resp.elements('code')).to include('unknown_attribute_type')
      end
    end
  end

  describe 'DELETE #delete' do
    context 'with valid user' do
      before do
        login user
        main_attribute
        delete :delete, params: { project: project,
                                  attribute: main_attribute.fullname,
                                  format: :xml }
      end

      it { expect(response).to be_success }
      it { expect(project.reload.attribs).to be_empty }
    end

    context 'with invalid user' do
      let(:wrong_user) { create(:confirmed_user, login: 'tomtom') }
      before do
        login wrong_user
        main_attribute
        delete :delete, params: { project: project,
                                  attribute: main_attribute.fullname,
                                  format: :xml }
      end

      it { expect(response).not_to be_success }
      it { expect(project.attribs).not_to be_empty }
      it 'gives the right status code' do
        resp = Xmlhash.parse(response.body)
        expect(resp.elements('code')).to include('change_attribute_no_permission')
      end
    end
  end
end
