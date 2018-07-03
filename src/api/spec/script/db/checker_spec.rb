require 'rails_helper'
require File.expand_path(File.join(Rails.root, 'db', 'checker'))

RSpec.describe DB::Checker do
  let!(:checker) { DB::Checker.new }

  describe '#warn_for_rerun' do
    it 'shows a warning message if failed' do
      allow(checker).to receive(:failed).and_return(true)
      expect { checker.warn_for_rerun }.to output(/WARNING/).to_stdout
    end

    it 'shows a greeting message if worked' do
      allow(checker).to receive(:failed).and_return(false)
      expect { checker.warn_for_rerun }.to output(/All checks passed/).to_stdout
    end
  end

  describe '#warn_for_environment' do
    it 'shows a warning message if not in production environment' do
      ENV['RAILS_ENV'] = 'test'
      expect { checker.warn_for_environment }.to output(/WARNING/).to_stdout
    end

    it 'shows nothing if in production environment' do
      ENV['RAILS_ENV'] = 'production'
      expect { checker.warn_for_environment }.not_to output.to_stdout
    end
  end

  describe '#initialize' do
    it "can't be failed before runnig" do
      expect(checker.failed).not_to be_truthy
    end
  end

  describe '#contraints_to_check' do
    it { expect(checker.contraints_to_check).to be_a Array }
    it { expect(checker.contraints_to_check).not_to be_empty }
    it 'constraints are well defined' do
      checker.contraints_to_check.each do |constraint|
        expect(constraint).to be_a Array
        expect(constraint.size).to be >= 3
        expect(constraint[0, 3]).to all(be_a Symbol)
        expect(constraint[3]).to be_in([true, false, nil])
      end
    end
  end

  describe '#check_foreign_keys' do
    context 'without inconsistent records' do
      before do
        allow(checker).to receive(:check_foreign_key).and_return([])
      end

      it { expect { checker.check_foreign_keys }.to output(/OK/).to_stdout }
      it { expect { checker.check_foreign_keys }.not_to output(/Trying to fix/).to_stdout }
    end

    context 'with inconsistent records' do
      before do
        allow(checker).to receive(:check_foreign_key).and_return([1, 2, 3])
        allow(checker).to receive(:ask_for_fixing)
      end

      it { expect { checker.check_foreign_keys }.to output(/FAIL/).to_stdout }
      it { expect { checker.check_foreign_keys }.to output(/Trying to fix/).to_stdout }
    end
  end

  describe '#resolve_devel_packages' do
    let(:project) { create(:project) }
    let(:package_without_cycle) do
      package = create(:package, project: project)
      package.develpackage = create(:package, project: project)
      package.save
    end
    let(:package_with_cycle) do
      package = create(:package, project: project)
      package.develpackage = package
      package.save
    end

    context 'without problematic packages' do
      before { package_without_cycle }

      it { expect { checker.resolve_devel_packages }.to output(/OK/).to_stdout }
      it { expect { checker.resolve_devel_packages }.not_to output(/Errors detected at project/).to_stdout }
    end

    context 'with problematic packages' do
      before { package_with_cycle }

      it { expect { checker.resolve_devel_packages }.to output(/FAIL/).to_stdout }
      it { expect { checker.resolve_devel_packages }.to output(/Errors detected at project/).to_stdout }
    end
  end
end
