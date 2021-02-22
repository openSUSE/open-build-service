require 'rails_helper'

RSpec.describe DistributionsController do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }

  let(:distribution_xml) do
    '<distributions>
       <distribution vendor="opensuse" version="Tumbleweed">
         <name>openSUSE Tumbleweed</name>
         <project>openSUSE:Factory</project>
         <reponame>openSUSE_Tumbleweed</reponame>
         <repository>snapshot</repository>
         <link>http://www.opensuse.org/</link>
         <icon width="8" height="8" url="https://static.opensuse.org/distributions/logos/opensuse.png"/>
         <icon width="16" height="16" url="https://static.opensuse.org/distributions/logos/opensuse.png"/>
         <architecture>i586</architecture>
         <architecture>x86_64</architecture>
       </distribution>
     </distributions>'
  end

  let(:invalid_distribution_xml) do
    '<distribution>
     </distribution>'
  end

  describe '#create' do
    before do
      login admin
    end

    subject { post :create, body: distribution_xml, format: :xml }

    context 'when xml is valid' do
      it { is_expected.to have_http_status(:ok) }
      it { expect { subject }.to change(Distribution, :count).by(1) }
    end

    context 'when xml is invalid' do
      subject { post :create, body: invalid_distribution_xml, format: :xml }

      it { expect { subject }.not_to change(Distribution, :count) }
      it { is_expected.to have_http_status(:bad_request) }
    end

    context 'when xml is empty' do
      subject { post :create, format: :xml }

      it { is_expected.to have_http_status(:bad_request) }
    end

    context 'when authenticating as a user' do
      before do
        login user
      end

      it { is_expected.to have_http_status(:forbidden) }
    end
  end
end
