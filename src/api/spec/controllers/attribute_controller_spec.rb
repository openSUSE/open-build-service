require 'rails_helper'

RSpec.describe AttributeController, type: :controller do
  render_views

  describe '#update' do
    let(:admin) { create(:admin_user) }
    let(:user) { create(:confirmed_user) }
    let(:attribute) { build(:attrib_type) }
    let(:namespace) { attribute.namespace }
    let(:name) { attribute.name }

    let(:xml_count_2) do
      "<definition namespace='#{namespace}' name='#{name}'>
        <count>2</count>
        <modifiable_by user='#{user.login}'/>
      </definition>"
    end

    it 'will create attribute on POST' do
      login admin
      post :update, body: xml_count_2, format: :xml, params: { namespace: namespace, name: name }
      expect(response.status).to eq(200)

      attrib = AttribType.find_by_namespace_and_name!(namespace, name)
      expect(attrib).not_to be_nil
      expect(attrib.namespace).to eq(namespace)
    end

    it 'will update on POST' do
      login admin

      attribute.save!
      expect(AttribType.find_by_name(attribute.fullname).value_count).to be_nil

      # update (yeah, API sucks)
      post :update, body: xml_count_2, format: :xml, params: { namespace: namespace, name: name }
      expect(response.status).to eq(200)
      expect(AttribType.find_by_name(attribute.fullname).value_count).to be(2)
    end
  end
end
