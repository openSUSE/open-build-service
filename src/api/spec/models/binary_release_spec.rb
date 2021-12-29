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
 