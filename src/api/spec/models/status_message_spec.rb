require 'rails_helper'

RSpec.describe StatusMessage do
  let(:admin_user) { create(:admin_user, login: 'admin') }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:message) }
  end

  describe '.from_xml' do
    before do
      allow(User).to receive(:session!).and_return(admin_user)
    end

    context 'xml is valid' do
      let(:xml) { '<status_message id="4"><message>foo</message><severity>information</severity></status_message>' }
      let(:status_message) { StatusMessage.from_xml(xml) }

      it { expect { status_message }.not_to raise_error }
      it { expect(status_message).to be_a(StatusMessage) }
    end

    context 'xml is invalid' do
      it { expect { StatusMessage.from_xml('') }.to raise_error(ActiveRecord::RecordInvalid) }
    end
  end
end
