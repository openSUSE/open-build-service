require 'rails_helper'

RSpec.describe AttributeController do
  render_views

  describe '#update' do
    let(:admin) { create(:admin_user) }
    let(:user) { create(:confirmed_user) }
    let(:attribute_namespace) { create(:attrib_namespace) }
    let(:attribute) { build(:attrib_type, attrib_namespace: attribute_namespace) }

    let(:xml_count_2) do
      "<definition namespace='#{attribute_namespace.name}' name='#{attribute.name}'>
        <count>2</count>
        <modifiable_by user='#{user.login}'/>
      </definition>"
    end

    it 'will create attribute on POST' do
      login admin
      post :update, body: xml_count_2, format: :xml, params: { namespace: attribute_namespace.name, name: attribute.name }
      expect(response.status).to eq(200)

      attrib = AttribType.find_by_namespace_and_name!(attribute_namespace.name, attribute.name)
      expect(attrib).not_to be_nil
      expect(attrib.namespace).to eq(attribute_namespace.name)
    end

    it 'will update on POST' do
      login admin

      attribute.save!
      expect(attribute.value_count).to be_nil

      # update (yeah, API sucks)
      post :update, body: xml_count_2, format: :xml, params: { namespace: attribute_namespace.name, name: attribute.name }
      expect(response.status).to eq(200)
      attribute.reload
      expect(attribute.value_count).to eq(2)
    end
  end
end
