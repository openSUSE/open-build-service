RSpec.describe DistributionsController do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }

  let(:distributions_xml) do
    '<distributions>
       <distribution vendor="openSUSE" version="Tumbleweed">
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
       <distribution vendor="openSUSE" version="15.3" id="17740">
         <name>openSUSE Leap 15.3</name>
         <project>openSUSE:Leap:15.3</project>
         <reponame>openSUSE_Leap_15.3</reponame>
         <repository>standard</repository>
         <link>http://www.opensuse.org/</link>
         <icon url="https://static.opensuse.org/distributions/logos/opensuse.png" width="8" height="8"/>
         <icon url="https://static.opensuse.org/distributions/logos/opensuse.png" width="16" height="16"/>
         <architecture>x86_64</architecture>
         <architecture>aarch64</architecture>
         <architecture>ppc64le</architecture>
       </distribution>
     </distributions>'
  end

  let(:distribution_xml) do
    '<distribution vendor="openSUSE" version="Tumbleweed">
      <name>openSUSE Tumbleweed</name>
      <project>openSUSE:Factory</project>
      <reponame>openSUSE_Tumbleweed</reponame>
      <repository>snapshot</repository>
      <link>http://www.opensuse.org/</link>
      <icon width="8" height="8" url="https://static.opensuse.org/distributions/logos/opensuse.png"/>
      <icon width="16" height="16" url="https://static.opensuse.org/distributions/logos/opensuse.png"/>
      <architecture>i586</architecture>
      <architecture>x86_64</architecture>
    </distribution>'
  end

  describe '#create' do
    subject { post :create, body: distribution_xml, format: :xml }

    before do
      login admin
    end

    it { is_expected.to have_http_status(:ok) }
    it { expect { subject }.to change(Distribution, :count).by(1) }

    context 'when xml is empty' do
      subject { post :create, format: :xml }

      it { expect { subject }.not_to change(Distribution, :count) }
      it { is_expected.to have_http_status(:bad_request) }
    end

    context 'when xml is invalid' do
      subject { post :create, body: distributions_xml, format: :xml }

      it { expect { subject }.not_to change(Distribution, :count) }
      it { is_expected.to have_http_status(:bad_request) }
    end
  end

  describe '#update' do
    subject { post :update, params: { id: distribution.id }, body: distribution_xml, format: :xml }

    let(:distribution) { create(:distribution, vendor: 'debian') }

    before do
      login admin
    end

    it { is_expected.to have_http_status(:ok) }

    it 'updates the distribution' do
      subject
      expect(distribution.reload.vendor).to eq('openSUSE')
    end

    context 'when xml is empty' do
      subject { post :update, params: { id: distribution.id }, format: :xml }

      before do
        distribution
      end

      it { expect { subject }.not_to change(Distribution, :count) }
      it { is_expected.to have_http_status(:bad_request) }
    end

    context 'when xml is invalid' do
      subject { post :create, body: distributions_xml, format: :xml }

      it { expect { subject }.not_to change(Distribution, :count) }
      it { is_expected.to have_http_status(:bad_request) }
    end
  end

  describe '#bulk_replace' do
    subject { put :bulk_replace, body: distributions_xml, format: :xml }

    let!(:distributions) { create_list(:distribution, 3) }

    before do
      login admin
    end

    it { is_expected.to have_http_status(:ok) }

    it 'replaces the distributions' do
      expect { subject }.to change(Distribution, :count).from(3).to(2)
    end

    it 'updates the distributions' do
      expect { subject }.to change { Distribution.where(vendor: 'openSUSE').count }.from(0).to(2)
    end

    context 'when xml is empty' do
      subject { post :bulk_replace, format: :xml }

      it { expect { subject }.not_to change(Distribution, :count) }
      it { is_expected.to have_http_status(:bad_request) }
    end

    context 'when xml is invalid' do
      subject { post :bulk_replace, body: distribution_xml, format: :xml }

      it { expect { subject }.not_to change(Distribution, :count) }
      it { is_expected.to have_http_status(:bad_request) }
    end
  end
end
