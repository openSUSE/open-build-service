require 'rails_helper'

RSpec.describe SessionControllerService::SessionCreator do
  let!(:admin_user) { create(:admin_user, login: 'Admin') }

  describe '.new' do
    let(:session_creator) do
      described_class.new(username: admin_user.login,
                          password: admin_user.password)
    end

    it { expect { session_creator }.not_to raise_error }
  end

  describe '.valid?' do
    context 'is valid' do
      let(:session_creator) do
        described_class.new(username: admin_user.login,
                            password: admin_user.password)
      end

      it { expect(session_creator).to be_valid }
    end

    context 'not valid' do
      let(:session_creator) do
        described_class.new(username: '',
                            password: '')
      end

      it { expect(session_creator).not_to be_valid }
    end
  end

  describe 'exist?' do
    context 'true' do
      let(:session_creator) do
        described_class.new(username: admin_user.login,
                            password: admin_user.password)
      end

      it { expect(session_creator).to exist }
    end

    context 'false' do
      let(:session_creator) do
        described_class.new(username: 'foo',
                            password: 'bar')
      end

      it { expect(session_creator).not_to exist }
    end
  end
end
