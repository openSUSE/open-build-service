require Rails.root.join('db/data/20181214100207_remove_duplicated_flags.rb')

RSpec.describe RemoveDuplicatedFlags, type: :migration do
  let(:data_migration) { RemoveDuplicateRepositories.new }

  describe 'up' do
    let(:project) { create(:project) }
    let!(:flag1) { create(:build_flag, status: 'disable', project: project) }
    let!(:flag2) { create(:publish_flag, status: 'disable', project: project) }
    let!(:flag3) do
      flag = build(:build_flag, status: 'disable', project: project)
      flag.save(validate: false)
      flag
    end
    let!(:flag4) do
      flag = build(:build_flag, status: 'enable', project: project)
      flag.save(validate: false)
      flag
    end

    before do
      RemoveDuplicatedFlags.new.up
    end

    it { expect(project.reload.flags).to contain_exactly(flag3, flag2) }
  end
end
