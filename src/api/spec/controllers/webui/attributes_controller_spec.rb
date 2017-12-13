require 'rails_helper'

RSpec.describe Webui::AttributeController do
  let!(:user) { create(:confirmed_user) }

  describe 'GET index' do
    it 'shows an error message when package does not exist' do
      get :index, params: { project: user.home_project, package: "Pok" }
      expect(response).to redirect_to(project_show_path(user.home_project))
      expect(flash[:error]).to eq("Package Pok not found")
    end

    it 'shows an error message when project does not exist' do
      get :index, params: { project: "Does:Not:Exist" }
      expect(response).to redirect_to(projects_path)
      expect(flash[:error]).to eq("Project not found: Does:Not:Exist")
    end
  end

  describe 'GET #new' do
    before do
      login user
    end

    context 'with package' do
      let(:package) { create(:package, project: user.home_project) }

      before do
        get :new, params: { project: user.home_project, package: package }
      end

      it { expect(assigns(:attribute).project_id).to be_nil }
      it { expect(assigns(:attribute).package_id).to eq(package.id) }
    end

    context 'without package' do
      before do
        get :new, params: { project: user.home_project }
      end

      it { expect(assigns(:attribute).project_id).to eq(user.home_project.id) }
      it { expect(assigns(:attribute).package_id).to be_nil }
    end
  end

  describe 'GET #edit' do
    let(:attrib_value) { build(:attrib_value, value: Faker::Lorem.sentence) }

    before do
      login user
    end

    context 'with a value_count defined in attrib_type' do
      context 'with the same amount of values, nothing changes' do
        let(:attrib_type) { create(:attrib_type, value_count: 1) }
        let!(:attrib) { create(:attrib, project: user.home_project, attrib_type: attrib_type, values: [attrib_value]) }

        before do
          get :edit, params: { project: user.home_project, attribute: attrib.fullname }
        end

        it { expect(assigns(:attribute).values.length).to be(assigns(:attribute).attrib_type.value_count) }
        it { expect(assigns(:attribute).values.last.value).not_to be_empty }
      end

      context 'with more values, nothing changes' do
        let(:attrib_type) { create(:attrib_type, value_count: 2) }
        let(:attrib_value_2) { build(:attrib_value, value: Faker::Lorem.sentence) }
        let!(:attrib) { create(:attrib, project: user.home_project, attrib_type: attrib_type, values: [attrib_value, attrib_value_2]) }

        before do
          attrib_type.value_count -= 1
          attrib_type.save
          get :edit, params: { project: user.home_project, attribute: attrib.fullname }
        end

        it { expect(assigns(:attribute).values.length).to be(assigns(:attribute).attrib_type.value_count + 1) }
        it { expect(assigns(:attribute).values.last.value).not_to be_empty }
      end

      context 'with less values, it fills up values till value_count' do
        let(:attrib_type) { create(:attrib_type, value_count: 1) }
        let!(:attrib) { create(:attrib, project: user.home_project, attrib_type: attrib_type, values: [attrib_value]) }

        before do
          attrib_type.value_count += 1
          attrib_type.save
          get :edit, params: { project: user.home_project, attribute: attrib.fullname }
        end

        it { expect(assigns(:attribute).values.length).to be(assigns(:attribute).attrib_type.value_count) }
        it { expect(assigns(:attribute).values.last.value).to be_empty }
      end
    end

    context 'without a value_count defined in attrib_type' do
      let(:attrib) { create(:attrib, project: user.home_project) }
      let!(:attrib_values_length_before) { attrib.values.length }

      before do
        get :edit, params: { project: user.home_project, attribute: attrib.fullname }
      end

      it { expect(assigns(:attribute).attrib_type.value_count).to be_nil }
      it { expect(assigns(:attribute).values.length).to eq(attrib_values_length_before) }
    end
  end

  describe 'POST #create' do
    let(:attribute_type_0) { create(:attrib_type, value_count: 0) }
    let(:attribute_type_1) { create(:attrib_type, value_count: 1) }
    let(:attribute_type_1_name) { "#{attribute_type_1.namespace}:#{attribute_type_1.name}" }

    before do
      login user
    end

    context 'with editable values' do
      before do
        post :create, params: { attrib: { project_id: user.home_project.id, attrib_type_id: attribute_type_1.id } }
      end

      it { expect(response).to redirect_to(edit_attribs_path(project: user.home_project_name, package: '', attribute: attribute_type_1_name)) }
      it { expect(flash[:notice]).to eq('Attribute was successfully created.') }
    end

    context 'with non editable values' do
      before do
        post :create, params: { attrib: { project_id: user.home_project.id, attrib_type_id: attribute_type_0.id } }
      end

      it { expect(response).to redirect_to(index_attribs_path(project: user.home_project_name, package: '')) }
      it { expect(flash[:notice]).to eq('Attribute was successfully created.') }
    end

    context 'fails at save' do
      before do
        allow_any_instance_of(Attrib).to receive(:save).and_return(false)
        post :create, params: { attrib: { project_id: user.home_project.id, attrib_type_id: attribute_type_1.id } }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe 'PATCH #update' do
    let(:attrib) { create(:attrib, project: user.home_project) }
    let(:new_attrib_type) { create(:attrib_type) }

    before do
      login user
    end

    context 'with valid parameters' do
      before do
        patch :update, params: { id: attrib.id, attrib: { attrib_type_id: new_attrib_type.id } }
        attrib.reload
      end

      it { expect(response).to redirect_to(edit_attribs_path(attribute: attrib.fullname, project: user.home_project.to_s, package: '')) }
      it { expect(flash[:notice]).to eq 'Attribute was successfully updated.' }
      it { expect(attrib.attrib_type_id).to eq new_attrib_type.id }
    end

    context 'with non valid parameters' do
      before do
        patch :update, params: { id: attrib.id, attrib: { attrib_type_id: nil } }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe 'DELETE #destroy' do
    let!(:attrib) { create(:attrib, project: user.home_project) }

    before do
      login user
    end

    it 'deletes the attrib' do
      expect {
        delete :destroy, params: { id: attrib.id }
      }.to change { Attrib.count }.by(-1)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq 'Attribute sucessfully deleted!'
    end
  end
end
