require 'rails_helper'

RSpec.describe ConsistencyCheckJobService::BaseConsistencyChecker, vcr: false do
  let(:base_consistency_checker) { described_class.new }

  describe '#dir_to_array' do
    let(:xml_hash) do
      Xmlhash::XMLHash.new({ 'entry' => [{ 'name' => 'home:Admin' }, { 'name' => 'super_bacana' }, { 'name' => 'super_project' }] })
    end

    it { expect(base_consistency_checker.dir_to_array(xml_hash)).to be_an(Array) }
    it { expect(base_consistency_checker.dir_to_array(xml_hash)).to eq(['home:Admin', 'super_bacana', 'super_project']) }
  end
end
