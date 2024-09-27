RSpec.describe FullTextSearch do
  let!(:project) { create(:project, name: 'test_project', title: '', description: '') }
  let(:another_project) { create(:project, name: 'test2', title: '', description: '') }
  let!(:another_package) { create(:package, name: 'test2', project: another_project, title: '', description: '') }

  describe '#search', :thinking_sphinx do
    subject { FullTextSearch.new(search_params).search }

    context 'for a non-existent project' do
      let(:search_params) { { text: 'non-existent-project' } }

      it { is_expected.to be_empty }
    end

    context 'for an existing package' do
      let(:package) { create(:package, name: 'test_package', project: project, title: '', description: '') }
      let(:search_params) { { text: package.name } }

      it { is_expected.to eql([package]) }

      context 'which is deleted' do
        before do
          package.destroy
        end

        it { is_expected.to be_empty }
      end
    end

    context 'for an existing project' do
      let!(:some_project) { create(:project) }
      let(:search_params) { { text: some_project.name } }

      it { is_expected.to eql([some_project]) }

      context 'which is deleted' do
        before do
          some_project.destroy
        end

        it { is_expected.to be_empty }
      end
    end

    context 'specifying classes' do
      let!(:project) { create(:project, name: 'test', title: '', description: '') }
      let!(:package) { create(:package, name: 'test', project: project, title: '', description: '') }
      let(:search_param_text) { { text: 'test' } }

      context 'without any class' do
        let(:search_params) { search_param_text }

        it { expect(subject).to eql([package, project]) }
      end

      context 'class project only' do
        let(:search_params) { search_param_text.merge(classes: ['project']) }

        it { expect(subject).to eql([project]) }
      end

      context 'class package only' do
        let(:search_params) { search_param_text.merge(classes: ['package']) }

        it { expect(subject).to eql([package]) }
      end

      context 'classes project and package' do
        let(:search_params) { search_param_text.merge(classes: %w[project package]) }

        it { expect(subject).to eql([package, project]) }
      end
    end

    context 'projects with similar names' do
      before do
        project_names = %w[BaseDistro BaseDistro2.0 BaseDistro2.0:LinkedUpdateProject BaseDistro3 BaseDistro:Update Devel:BaseDistro:Update home:adrian:BaseDistro]

        project_names.each do |name|
          create(:project, name: name, title: '', description: '')
        end
      end

      context 'search for basedistro' do
        let(:search_params) { { text: 'basedistro' } }
        let(:expected_names) { %w[BaseDistro BaseDistro:Update Devel:BaseDistro:Update home:adrian:BaseDistro] }

        it { expect(subject.pluck(:name)).to eql(expected_names) }
      end
    end

    context 'develpackage' do
      let(:kdelibs_devel_package) { create(:package, name: 'kdelibs_devel_package', title: '', description: '') }
      let!(:kdelibs) { create(:package, name: 'kdelibs', title: '', description: '', develpackage: kdelibs_devel_package) }

      context 'search for kdelibs' do
        let(:search_params) { { text: 'kdelibs' } }

        it { expect(subject).to eql([kdelibs, kdelibs_devel_package]) }
      end

      context 'search for kdelibs_devel' do
        let(:search_params) { { text: 'kdelibs_devel' } }

        it { expect(subject).to eql([kdelibs_devel_package]) }
      end

      context 'search for "kdelibs devel", using two words' do
        let(:search_params) { { text: 'kdelibs devel' } }

        it { expect(subject).to eql([kdelibs_devel_package]) }
      end
    end

    context 'issues' do
      let(:package) { create(:package, project: project, title: 'Package title', description: '') }
      let(:issue_tracker) { IssueTracker.find_by(name: 'bnc') }
      let(:issue) { create(:issue, issue_tracker_id: issue_tracker.id, name: '123456') }
      let(:package_issue) { create(:package_issue, package: package, issue: issue) }

      before do
        package
        project.reload
        package_issue
      end

      context 'existent issue' do
        let(:search_params) { { issue_tracker_name: issue_tracker.name, issue_name: issue.name } }

        it { expect(subject).to contain_exactly(package, project) }
      end

      context 'existent issue searching by project only' do
        let(:search_params) { { issue_tracker_name: issue_tracker.name, issue_name: issue.name, classes: ['project'] } }

        it { expect(subject).to contain_exactly(project) }
      end

      context 'existent issue and non-existent text' do
        let(:search_params) { { issue_tracker_name: issue_tracker.name, issue_name: issue.name, text: 'Fake text' } }

        it { expect(subject).to be_empty }
      end

      context 'existent issue and existent text' do
        let(:search_params) { { issue_tracker_name: issue_tracker.name, issue_name: issue.name, text: 'Package title' } }

        it { expect(subject).to contain_exactly(package) }
      end

      context 'non-existent issue' do
        let(:search_params) { { issue_tracker_name: issue_tracker.name, issue_name: '999999' } }

        it { expect(subject).to be_empty }
      end

      context 'non-existent issue and non-existent text' do
        let(:search_params) { { issue_tracker_name: issue_tracker.name, issue_name: '999999', text: 'Fake text' } }

        it { expect(subject).to be_empty }
      end

      context 'non-existent issue and text' do
        let(:search_params) { { issue_tracker_name: issue_tracker.name, issue_name: '999999', text: 'Package' } }

        it { expect(subject).to be_empty }
      end
    end

    context 'attribs' do
      context 'for projects' do
        let(:attrib) { create(:template_attrib, project: project) }
        let(:project2) { create(:project, name: 'test_project_2', title: 'This is another project', description: '') }
        let!(:attrib_for_project2) { create(:template_attrib, project: project2) }

        context 'existent attrib' do
          let(:search_params) { { attrib_type_id: attrib.attrib_type_id } }

          before do
            PopulateToSphinxJob.perform_now(id: attrib.id, model_name: :attrib,
                                            reference: :package, path: [:package])
            PopulateToSphinxJob.perform_now(id: attrib.id, model_name: :attrib,
                                            reference: :project, path: [:project])
          end

          it { expect(subject).to contain_exactly(project, project2) }
        end

        context 'existent attrib with text' do
          let(:search_params) { { attrib_type_id: attrib.attrib_type_id, text: 'another' } }

          it { expect(subject).to contain_exactly(project2) }
        end
      end

      context 'for packages' do
        let(:package) { create(:package, project: project) }
        let(:attrib) { create(:maintained_attrib, package: package) }
        let(:package2) { create(:package, project: project, name: 'test_package_2', title: 'This is another package', description: '') }
        let!(:attrib_for_package2) { create(:maintained_attrib, package: package2) }

        context 'existent attrib' do
          let(:search_params) { { attrib_type_id: attrib.attrib_type_id } }

          it { expect(subject).to contain_exactly(package, package2) }
        end

        context 'existent attrib with text' do
          let(:search_params) { { attrib_type_id: attrib.attrib_type_id, text: 'another' } }

          it { expect(subject).to contain_exactly(package2) }
        end
      end
    end

    context 'hidden project and package' do
      let(:user) { create(:confirmed_user) }
      let(:other_user) { create(:confirmed_user) }
      let(:admin_user) { create(:admin_user) }
      let(:project) { create(:forbidden_project, name: 'hidden_project', title: '', description: '') }
      let(:package) { create(:package, name: 'hidden_package', project: project, title: '', description: '') }
      let!(:relationship) { create(:relationship_project_user, project: project, user: user) }

      context 'for a hidden project' do
        let(:search_params) { { text: project.name } }

        it { expect(subject).to be_empty }

        context 'with admin user' do
          before do
            login admin_user
          end

          it { expect(subject).to contain_exactly(project) }
        end

        context 'with normal user' do
          before do
            login other_user
          end

          it { expect(subject).to be_empty }
        end
      end

      context 'for a hidden package' do
        let(:search_params) { { text: package.name } }

        it { expect(subject).to be_empty }

        context 'with admin user' do
          before do
            login admin_user
          end

          it { expect(subject).to contain_exactly(package) }
        end

        context 'with normal user' do
          before do
            login other_user
          end

          it { expect(subject).to be_empty }
        end
      end
    end
  end
end
