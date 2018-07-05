require 'rails_helper'

RSpec.describe ObsFactory::StagingProject do
  let(:distribution) { ObsFactory::Distribution.new(create(:project, name: 'openSUSE:Factory')) }

  describe '::find' do
    subject { ObsFactory::StagingProject.find(distribution, '42') }

    context 'when there is a matching project' do
      let!(:project) { create(:project, name: 'openSUSE:Factory:Staging:42') }

      it 'returns the staging project' do
        is_expected.to be_kind_of ObsFactory::StagingProject
        expect(subject.name).to eq 'openSUSE:Factory:Staging:42'
        expect(subject.project).to eq project
        expect(subject.distribution).to eq distribution
      end
    end

    context 'when there is no matching project' do
      it { is_expected.to be_nil }
    end
  end

  describe '#adi_staging?' do
    let(:project) { create(:project, name: 'openSUSE:Factory:Staging:adi:42') }

    subject { ObsFactory::StagingProject.new(project: project, distribution: distribution) }

    context "when the project name includes 'Staging:adi'" do
      let(:project) { create(:project, name: 'openSUSE:Factory:Staging:adi:42') }

      it { expect(subject.adi_staging?).to be true }
    end

    context "when the project name does not include 'Staging:adi'" do
      let(:project) { create(:project, name: 'openSUSE:Factory:Staging:42') }

      it { expect(subject.adi_staging?).to be false }
    end
  end
end
