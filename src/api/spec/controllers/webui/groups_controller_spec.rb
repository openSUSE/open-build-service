require 'rails_helper'

RSpec.describe Webui::GroupsController do
  let(:group) { create(:group) }
  let(:another_group) { create(:group, title: "#{group.title}-#{SecureRandom.hex}" ) }

  # except [:show, :tokens, :autocomplete]
  it { is_expected.to use_before_action(:require_login) }
  # only: [:show, :update, :edit]
  it { is_expected.to use_before_action(:set_group) }
  # except: [:show, :autocomplete, :tokens]
  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'GET show' do
    it 'is successful as nobody' do
      get :show, params: { title: group.title }
      expect(response).to have_http_status(:success)
    end

    it 'assigns @group' do
      get :show, params: { title: group.title }
      expect(assigns(:group)).to eq(group)
    end

    it 'redirects to root_path if group does not exist' do
      get :show, params: { title: 'Foobar' }
      expect(flash[:error]).to eq("Group 'Foobar' does not exist")
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET tokens' do
    it 'returns a hash with one group for a match' do
      get :tokens, params: { q: group.title }
      expect(response.body).to eq([{ name: group.title }].to_json)
    end

    it 'returns a hash with more than one group for a match' do
      another_group # necessary for initialization
      get :tokens, params: { q: group.title }
      expect(response.body).to eq([{ name: group.title }, { name: another_group.title }].to_json)
    end

    it 'returns empty hash if no match' do
      get :tokens, params: { q: 'no_group' }
      expect(response.body).to eq([].to_json)
    end
  end

  describe 'GET autocomplete' do
    it 'returns list with one group for a match' do
      get :autocomplete, params: { term: group.title }
      expect(response.body).to eq([group.title].to_json)
    end

    it 'returns list with more than one group for a match' do
      another_group # necessary for initialization
      get :autocomplete, params: { term: group.title }
      expect(response.body).to eq([group.title, another_group.title].to_json)
    end

    it 'returns empty list if no match' do
      get :autocomplete, params: { term: 'no_group' }
      expect(response.body).to eq([].to_json)
    end
  end
end
