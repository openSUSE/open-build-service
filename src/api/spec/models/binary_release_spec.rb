require 'rails_helper'

RSpec.describe BinaryRelease do
  let(:binary_hash) do
    {
      'disturl' => '/foo/bar',
      'supportstatus' => 'foo',
      'binaryid' => '31337',
      'buildtime' => '1640772016',
      'binaryarch' => 'i386',
      'name' => 'foo'
    }
  end

  let(:user) { create(:confirmed_user, :with_home, login: 'foo') }
  let!(:repository) { create(:repository, project: user.home_project) }

  describe '.update_binary_releases' do
    subject { described_class.update_binary_releases(repository, 'foo') }

    context 'no binary release existed before' do
      before do
        allow(Backend::Api::Server).to receive(:notification_payload).and_return([binary_hash].to_json)
        allow(Backend::Api::Server).to receive(:delete_notification_payload).and_return('')
      end

      it { expect { subject }.not_to raise_error }
      it { expect { subject }.to change(BinaryRelease, :count).by(1) }
    end

    context 'an existing binary release should be updated' do
      let!(:binary_release) { create(:binary_release, repository: repository) }
      let(:repeated_binary_hash) do
        {
          'disturl' => binary_release.binary_disturl,
          'supportstatus' => binary_release.binary_supportstatus,
          'binaryid' => '31338', # change a value to avoid both objects to be identical
          'buildtime' => binary_release.binary_buildtime,
          'name' => binary_release.binary_name,
          'binaryarch' => binary_release.binary_arch
        }
      end

      before do
        allow(Backend::Api::Server).to receive(:notification_payload).and_return([repeated_binary_hash].to_json)
        allow(Backend::Api::Server).to receive(:delete_notification_payload).and_return('')
        subject
      end

      it { expect(BinaryRelease.first.modify_time).not_to be_nil }
      it { expect(BinaryRelease.last.binary_id).to eq('31338') }
      it { expect(BinaryRelease.last.operation).to eq('modified') }
    end
  end

  describe '.update_binary_releases_via_json' do
    context 'with empty json' do
      it { expect { described_class.update_binary_releases_via_json(repository, []) }.not_to raise_error }
    end

    context 'with a repository to be released' do
      let!(:binary_release) { create(:binary_release, repository: repository) }
      let(:repeated_binary_hash) do
        {
          'disturl' => binary_release.binary_disturl,
          'supportstatus' => binary_release.binary_supportstatus,
          'binaryid' => binary_release.binary_id,
          'buildtime' => binary_release.binary_buildtime,
          'name' => binary_release.binary_name,
          'binaryarch' => binary_release.binary_arch
        }
      end

      it { expect { described_class.update_binary_releases_via_json(repository, [repeated_binary_hash]) }.not_to raise_error }
    end

    context 'with repeated binary_releases' do
      let!(:binary_releases) { create_list(:binary_release, 2, repository: repository) }
      let(:repeated_binary_hash) do
        {
          'disturl' => binary_releases.first.binary_disturl,
          'supportstatus' => binary_releases.first.binary_supportstatus,
          'binaryid' => binary_releases.first.binary_id,
          'buildtime' => binary_releases.first.binary_buildtime.to_i,
          'name' => binary_releases.first.binary_name,
          'binaryarch' => binary_releases.first.binary_arch
        }
      end

      subject { described_class.update_binary_releases_via_json(repository, [repeated_binary_hash]) }

      it { expect { subject }.to change(BinaryRelease, :count).by(-1) }
    end
  end

  describe '#identical_to?' do
    context 'binary_release and binary_hash are identical' do
      let(:binary_release) do
        BinaryRelease.new(
          binary_disturl: binary_hash['disturl'],
          binary_supportstatus: binary_hash['supportstatus'],
          binary_id: binary_hash['binaryid'],
          binary_buildtime: Time.strptime(binary_hash['buildtime'], '%s')
        )
      end

      it { expect(binary_release).to be_identical_to(binary_hash) }
    end

    context 'binary_release and binary_hash are not identical' do
      let(:binary_release) do
        BinaryRelease.new(
          binary_disturl: binary_hash['disturl'],
          binary_supportstatus: binary_hash['supportstatus'],
          binary_id: binary_hash['binaryid'],
          binary_buildtime: nil
        )
      end

      it { expect(binary_release).not_to be_identical_to(binary_hash) }
    end
  end
end
