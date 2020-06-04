require 'rails_helper'

RSpec.describe ProjectStatus::Calculator, vcr: true do
  let!(:project) do
    create(:project_with_packages,
           name: 'project_used_for_restoration',
           title: 'restoration_project_title',
           package_title: 'restoration_title',
           package_description: 'restoration_desc',
           package_name: 'restoration_package')
  end

  describe '#initialize' do
    it { expect { described_class.new(project) }.not_to raise_error }
  end

  describe '#calc_status' do
    subject { described_class.new(project).calc_status }

    it { expect { subject }.not_to raise_error }
    it { expect(subject).not_to be_nil }
    it { expect(subject).to be_a(Hash) }
    it { expect(subject.keys).not_to be_empty }

    context 'pure_project' do
      subject { described_class.new(project).calc_status(pure_project: true) }

      it { expect { subject }.not_to raise_error }
      it { expect(subject).not_to be_nil }
      it { expect(subject).to be_a(Hash) }
      it { expect(subject.keys).not_to be_empty }
    end
  end
end
