# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EventMailerHelper do
  let(:project) { create(:project_with_package, name: 'MyProject', package_name: 'MyPackage') }
  let(:package) { project.packages.first }

  describe '#project_or_package_text' do
    context 'with a project' do
      context 'with a package' do
        it { expect(project_or_package_text(project, package)).to eq('package MyProject/MyPackage') }
      end

      context 'without a package' do
        it { expect(project_or_package_text(project, nil)).to eq('project MyProject') }
      end
    end

    context 'without a project' do
      context 'with a package' do
        it { expect(project_or_package_text(nil, package)).to eq('package /MyPackage') }
      end

      context 'without a package' do
        it { expect(project_or_package_text(nil, nil)).to eq('project ') }
      end
    end
  end
end
