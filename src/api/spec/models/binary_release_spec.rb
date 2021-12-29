require 'rails_helper'

RSpec.describe BinaryRelease do
  let(:binary_hash) do
    {
      'disturl' => '/foo/bar',
      'supportstatus' => 'foo',
      'binaryid' => '31337',
      'buildtime' => '1640772016'
    }
  end

  describe '.update_binary_releases_via_json' do
    let(:user) { create(:confirmed_user, :with_home, login: 'foo') }
    let!(:repository) { create(:repository, project: user.home_project) }

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
