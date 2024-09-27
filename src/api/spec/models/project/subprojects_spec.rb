RSpec.describe Project do
  describe '#parent' do
    let!(:project_a) { create(:project, name: 'A') }
    let!(:project_b_c) { create(:project, name: 'A:B:C') }
    let!(:project_d) { create(:project, name: 'A:B:C:D') }

    it 'returns the parent project' do
      expect(project_d.parent).to eq(project_b_c)
      expect(project_b_c.parent).to eq(project_a)
      expect(project_a.parent).to be_nil
    end
  end

  describe '#ancestors' do
    let!(:project_a) { create(:project, name: 'A') }
    let!(:sub_project_b_c) { create(:project, name: 'A:B:C') }
    let!(:sub_project_d) { create(:project, name: 'A:B:C:D') }
    let!(:sub_project_e) { create(:project, name: 'A:B:C:D:E') }

    it { expect(sub_project_e.ancestors).to contain_exactly(project_a, sub_project_b_c, sub_project_d) }
  end

  describe '#possible_ancestor_names' do
    subject { subproject.possible_ancestor_names }

    let(:subproject) { create(:project, name: 'A:B:C:D') }

    it 'returns an ordered list of possible parent project names' do
      expect(subject).to contain_exactly('A', 'A:B', 'A:B:C')
      expect(subject[0]).to eq('A:B:C')
      expect(subject[1]).to eq('A:B')
      expect(subject[2]).to eq('A')
    end
  end

  describe '#siblingprojects' do
    let!(:project_a) { create(:project, name: 'A') }
    let!(:sibling1) { create(:project, name: 'A:1') }
    let!(:sibling2) { create(:project, name: 'A:2') }
    let!(:sibling3) { create(:project, name: 'A:3') }

    it 'returns all projects that have the same parent project' do
      expect(sibling1.siblingprojects).to contain_exactly(sibling2, sibling3)
      expect(project_a.siblingprojects).to be_empty
    end
  end

  describe '#subprojects' do
    let!(:project_a) { create(:project, name: 'A') }
    let!(:sub_project_b) { create(:project, name: 'A:B') }
    let!(:sub_project_c) { create(:project, name: 'A:B:C') }
    let!(:sub_project_d) { create(:project, name: 'A:B:C:D') }

    it 'returns all subprojects of a project' do
      expect(project_a.subprojects).to contain_exactly(sub_project_b, sub_project_c, sub_project_d)
      expect(sub_project_b.subprojects).to contain_exactly(sub_project_c, sub_project_d)
      expect(sub_project_d.subprojects).to be_empty
    end
  end
end
