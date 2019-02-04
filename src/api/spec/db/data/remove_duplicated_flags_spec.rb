require 'rails_helper'
require Rails.root.join('db/data/20181214100207_remove_duplicated_flags.rb')

RSpec.describe RemoveDuplicatedFlags, type: :migration do
  let(:data_migration) { RemoveDuplicateRepositories.new }

  describe 'up' do
    let(:project) { create(:project) }
    let!(:flag_1) { create(:build_flag, status: 'disable', project: project) }
    let!(:flag_2) { create(:publish_flag, status: 'disable', project: project) }
    let!(:flag_3) do
      flag = build(:build_flag, status: 'disable', project: project)
      flag.save(validate: false)
      flag
    end
    let!(:flag_4) do
      flag = build(:build_flag, status: 'enable', project: project)
      flag.save(validate: false)
      flag
    end

    before do
      RemoveDuplicatedFlags.new.up
    end

    it { expect(project.reload.flags).to contain_exactly(flag_3, flag_2) }
  end
end
