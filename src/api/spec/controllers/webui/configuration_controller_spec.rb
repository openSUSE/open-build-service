require 'rails_helper'

RSpec.describe Webui::ConfigurationController do
  let(:confirmed_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  it { is_expected.to use_before_action(:require_admin) }

  describe 'PATCH #update' do
    context 'as admin' do
      before do
        login(admin_user)
        patch :update, params: { configuration: { name: 'obs', title: 'OBS', description: 'something',
                                                  unlisted_projects_filter: '^home:fake_user:.*', unlisted_projects_filter_description: "fake_user's home" } }
      end

      it { expect(response).to redirect_to(configuration_path) }
      it { expect(flash[:success]).to eq('Configuration was successfully updated.') }
      it { expect(::Configuration.first.name).to eq('obs') }
      it { expect(::Configuration.first.title).to eq('OBS') }
      it { expect(::Configuration.first.description).to eq('something') }
      it { expect(::Configuration.first.unlisted_projects_filter).to eq('^home:fake_user:.*') }
      it { expect(::Configuration.first.unlisted_projects_filter_description).to eq("fake_user's home") }
    end
  end
end
