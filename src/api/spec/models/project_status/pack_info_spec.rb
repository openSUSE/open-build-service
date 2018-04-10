# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectStatus::PackInfo do
  let(:package) { create(:package) }
  let(:pack_info) { ProjectStatus::PackInfo.new(package) }
  let(:now) { Time.now }
  let(:one_hour_ago) { now - 1.hour }
  let(:two_hours_ago) { now - 2.hours }

  describe '.set_versrel' do
    before do
      # We have to call it initially to set the variables because they're not accessible from outside
      pack_info.set_versrel('1.0-42', one_hour_ago)
    end

    RSpec.shared_examples 'a PackInfo object' do
      it { expect(pack_info.versiontime).to eq(time) }
      it { expect(pack_info.version).to eq(version) }
      it { expect(pack_info.release).to eq(release) }
    end

    context 'with older version time' do
      let(:time) { one_hour_ago }
      let(:version) { '1.0' }
      let(:release) { '42' }

      before do
        pack_info.set_versrel('2.0-43', two_hours_ago)
      end

      it_should_behave_like 'a PackInfo object'
    end

    context 'with newer version time' do
      let(:time) { now }
      let(:release) { '43' }

      context 'with short version ' do
        let(:version) { '2.0' }

        before do
          pack_info.set_versrel("#{version}-#{release}", time)
        end

        it_should_behave_like 'a PackInfo object'
      end

      context 'with long version' do
        let(:version) { '2.0-2.0' }

        before do
          pack_info.set_versrel("#{version}-#{release}", time)
        end

        it_should_behave_like 'a PackInfo object'
      end
    end
  end

  describe '.failure' do
    let(:repository) { 'standard' }
    let(:architecture) { 'x86_64' }
    let(:md5) { 'acbd18db4cc2f85cedef654fccc4a4d8' }

    before do
      # We have to call it initially to set the variables because they're not accessible from outside
      pack_info.failure(repository, architecture, one_hour_ago, md5)
    end

    it 'sets @failed attribute' do
      expect(pack_info.failed).to eq({ standard: [one_hour_ago, architecture, md5] }.with_indifferent_access)
    end

    context 'with a failure with newer time and different md5' do
      let(:new_md5) { 'NEWd18db4cc2f85cedef654fccc4aNEW' }

      before do
        pack_info.failure(repository, architecture, now, new_md5)
      end

      it 'updates md5 but not time' do
        expect(pack_info.failed).to eq({ standard: [one_hour_ago, architecture, new_md5] }.with_indifferent_access)
      end
    end

    context 'with a failure with newer time and different md5' do
      let(:new_md5) { 'NEWd18db4cc2f85cedef654fccc4aNEW' }

      before do
        pack_info.failure(repository, architecture, two_hours_ago, new_md5)
      end

      it 'updates md5 but not time' do
        expect(pack_info.failed).to eq({ standard: [two_hours_ago, architecture, new_md5] }.with_indifferent_access)
      end
    end
  end
end
