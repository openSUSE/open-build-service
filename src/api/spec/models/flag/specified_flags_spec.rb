require 'rails_helper'

RSpec.describe Flag::SpecifiedFlags do
  let(:project) { create(:project_with_repository) }
  let(:package) { create(:package, project: project) }
  let(:repository_name) { project.repositories.first.name }
  let(:architecture_name) { project.repositories.first.architectures.first.name }
  let(:flag_type) { 'build' }

  context 'new project' do
    subject { Flag::SpecifiedFlags.new(project, flag_type) }

    it 'has nothing user specified' do
      expect(subject).not_to be_set_by_user(nil, nil)
      expect(subject).not_to be_set_by_user(repository_name, architecture_name)
    end

    it 'has default status on effective flag' do
      expect(subject.effective_flag(nil, nil).status).to eq(FlagHelper.default_for(flag_type))
      expect(subject.effective_flag(repository_name, architecture_name).status).to eq(FlagHelper.default_for(flag_type))
    end
  end

  context 'new package' do
    subject { Flag::SpecifiedFlags.new(package, flag_type) }

    it 'has nothing user specified' do
      expect(subject).not_to be_set_by_user(nil, nil)
      expect(subject).not_to be_set_by_user(repository_name, architecture_name)
    end

    it 'has default status on effective flag' do
      expect(subject.effective_flag(nil, nil).status).to eq(FlagHelper.default_for(flag_type))
      expect(subject.effective_flag(repository_name, architecture_name).status).to eq(FlagHelper.default_for(flag_type))
    end
  end

  context 'project is disabled' do
    before do
      project.flags.create(status: :disable, flag: flag_type)
    end

    context 'package' do
      subject { Flag::SpecifiedFlags.new(package, flag_type) }

      it 'has nothing user specified' do
        expect(subject).not_to be_set_by_user(nil, nil)
        expect(subject).not_to be_set_by_user(repository_name, architecture_name)
      end

      it 'effective flag is disabled' do
        expect(subject.effective_flag(nil, nil).status).to eq('disable')
        expect(subject.effective_flag(repository_name, architecture_name).status).to eq('disable')
      end

      context 'enabled flag for repo' do
        before do
          package.flags.create(status: :enable, flag: flag_type, repo: repository_name)
        end

        it 'has one thing user specified' do
          expect(subject).not_to be_set_by_user(nil, nil)
          expect(subject).not_to be_set_by_user(repository_name, architecture_name)
          expect(subject).to be_set_by_user(repository_name, nil)
        end

        it 'effective flag is still disabled for all' do
          expect(subject.effective_flag(nil, nil).status).to eq('disable')
        end

        it 'effective flag on repo is enabled' do
          expect(subject.effective_flag(repository_name, architecture_name).status).to eq('enable')
        end

        it 'default flag is from project' do
          expect(subject.default_flag(repository_name, nil).status).to eq('disable')
        end
      end
    end

    context 'project' do
      subject { Flag::SpecifiedFlags.new(project, flag_type) }

      it 'has global flag user specified' do
        expect(subject.set_by_user?(nil, nil)).to be(true)
        expect(subject).not_to be_set_by_user(repository_name, architecture_name)
      end

      it 'effective flag is disabled' do
        expect(subject.effective_flag(nil, nil).status).to eq('disable')
        expect(subject.effective_flag(repository_name, architecture_name).status).to eq('disable')
      end

      it 'default flag is enabled' do
        expect(subject.default_flag(nil, nil).status).to eq(FlagHelper.default_for(flag_type))
      end
    end
  end
end
