require 'rails_helper'

RSpec.describe Webui::ArchitecturesController do
  let(:confirmed_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  it { is_expected.to use_before_action(:require_admin) }

  describe 'POST #bulk_update_availability' do
    context 'as admin' do
      it 'creates the architectures' do
        login(admin_user)

        post :bulk_update_availability, params: { archs: { i586: '0', s390x: '1' } }
        expect(response).to redirect_to(architectures_path)
        expect(flash[:notice]).to eq('Architectures successfully updated.')
        expect(Architecture.find_by_name('i586').available).to be false
        expect(Architecture.find_by_name('s390x').available).to be true
      end
    end
  end
end
