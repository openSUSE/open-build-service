RSpec.describe Webui::RequestHelper do
  let(:target_package) { create(:package) }
  let(:target_project) { target_package.project }
  let(:source_package) { create(:package, :as_submission_source) }

  describe '#new_or_update' do
    context 'for submitting a new package' do
      let(:bs_request_with_submit_action) do
        create(:bs_request_with_submit_action,
               target_project: target_project,
               target_package: 'does-not-exist-yet',
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row.new(bs_request_with_submit_action) }

      it { expect(new_or_update_request(row)).to eq('submit <small>(new package)</small>') }
      it { expect(new_or_update_request(row)).to be_a(ActiveSupport::SafeBuffer) }
    end

    context 'for releasing a package' do
      let(:bs_request_with_maintenance_release_action) do
        create(:bs_request_with_maintenance_release_actions,
               target_package: target_package,
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row.new(bs_request_with_maintenance_release_action) }

      it { expect(new_or_update_request(row)).to eq('release') }
    end

    context 'for submitting an existing package' do
      let(:bs_request_with_submit_action) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row.new(bs_request_with_submit_action) }

      it { expect(new_or_update_request(row)).to eq('submit') }
    end
  end

  describe '#calculate_filename' do
    let(:filename) { 'apache2' }

    context 'for deleted files' do
      let(:file_element) do
        { state: 'deleted' }.with_indifferent_access
      end

      it { expect(calculate_filename(filename, file_element)).to eq(filename) }
    end

    context 'for added files' do
      let(:file_element) do
        { state: 'added' }.with_indifferent_access
      end

      it { expect(calculate_filename(filename, file_element)).to eq(filename) }
    end

    context 'for changed files' do
      let(:file_element) do
        { state: 'changed', old: { name: filename } }.with_indifferent_access
      end
      let(:new_filename) { 'apache3' }

      it { expect(calculate_filename(filename, file_element)).to eq(filename) }
      it { expect(calculate_filename(new_filename, file_element)).to eq("#{filename} -> #{new_filename}") }
    end

    context 'for renamed files' do
      let(:file_element) do
        { state: 'renamed', old: { name: filename } }.with_indifferent_access
      end
      let(:new_filename) { 'apache3' }

      it { expect(calculate_filename(new_filename, file_element)).to eq("#{filename} -> #{new_filename}") }
    end
  end

  context 'source diffs' do
    let(:source_diff) do
      {
        'old' => {
          'project' => 'home:Admin',
          'package' => 'obs-server',
          'rev' => 12
        },
        'new' => {
          'project' => 'home:tux',
          'package' => 'koji',
          'rev' => 13
        }
      }
    end

    describe '#diff_label' do
      it { expect(diff_label(source_diff['old'])).to eq('home:Admin / obs-server (rev 12)') }
    end

    describe '#diff_data' do
      context "when it's a delete request" do
        subject { diff_data(:delete, source_diff) }

        it { is_expected.to match(project: 'home:Admin', package: 'obs-server', rev: 12, expand: 1) }
      end

      context "when it's not a delete request" do
        subject { diff_data(:submit, source_diff) }

        it { is_expected.to match(project: 'home:tux', package: 'koji', rev: 13, expand: 1) }
      end
    end
  end

  describe '#request_action_header' do
    let(:creator) { create(:confirmed_user, login: 'request_creator') }
    let(:requester) { create(:confirmed_user, login: 'requester') }
    let(:target_package) { create(:package) }
    let(:source_package) { create(:package) }
    let(:action) do
      {
        tprj: target_package.project.name,
        tpkg: target_package.name,
        sprj: source_package.project.name,
        spkg: source_package.name
      }
    end

    context 'when action is :delete' do
      subject { request_action_header(action.merge(type: :delete), creator.login) }

      let(:expected_regex) do
        Regexp.new("Delete package .*#{project_show_path(target_package.project)}.* / .*" +
                   package_show_path(target_package.project, target_package).to_s)
      end

      it { is_expected.to match(expected_regex) }

      context 'with a target repository' do
        subject { request_action_header(action.merge(type: :delete, trepo: target_repository.name), creator.login) }

        let(:target_repository) { create(:repository, project: target_package.project) }
        let(:expected_regex) do
          Regexp.new("Delete repository .*#{Regexp.escape(repositories_path(project: target_repository.project, repository: target_repository.name))}.* for package .*" \
                     "#{project_show_path(target_package.project)}.* / .*#{package_show_path(target_package.project, target_package)}")
        end

        it { is_expected.to match(expected_regex) }
      end
    end

    context 'when action is :add_role' do
      subject { request_action_header(action.merge(type: :add_role, user: requester.login, role: 'maintainer'), creator.login) }

      let(:expected_regex) do
        Regexp.new("#{creator.realname} \\(request_creator\\).* wants the user .*#{requester.realname} \\(requester\\).* " \
                   "to get the role maintainer for package .*#{target_package.project}.* / .*#{target_package}")
      end

      it { is_expected.to match(expected_regex) }
    end

    context 'when action is :change_devel' do
      subject { request_action_header(action.merge(type: :change_devel), creator.login) }

      let(:expected_regex) do
        Regexp.new("Set the devel project to package .*#{source_package.project}.* / .*#{source_package}.* " \
                   "for package .*#{target_package.project}.* / .*#{target_package}")
      end

      it { is_expected.to match(expected_regex) }
    end

    context 'when action is :maintenance_incident' do
      subject { request_action_header(action.merge(type: :maintenance_incident), creator.login) }

      let(:expected_regex) do
        Regexp.new("Submit update from package .*#{source_package.project}.* / .*#{source_package}.* to package " \
                   ".*#{target_package.project}.* / .*#{target_package}")
      end

      it { is_expected.to match(expected_regex) }
    end

    context 'when action is :maintenance_release' do
      subject { request_action_header(action.merge(type: :maintenance_release), creator.login) }

      let(:expected_regex) do
        Regexp.new("Maintenance release package .*#{source_package.project}.* / .*#{source_package}.* to package " \
                   ".*#{target_package.project}.* / .*#{target_package}.* ")
      end

      it { is_expected.to match(expected_regex) }
    end
  end

  describe '#next_prev_path' do
    context 'when user is on request show page' do
      it { expect(next_prev_path(number: 10, request_action_id: 30)).to eq('/request/show/10/request_action/30') }
    end

    context 'when user is on build results page' do
      it { expect(next_prev_path(number: 10, request_action_id: 30, page_name: 'request_build_results')).to eq('/requests/10/actions/30/build_results') }
    end

    context 'when user is on rpm lint page' do
      it { expect(next_prev_path(number: 10, request_action_id: 30, page_name: 'request_rpm_lint')).to eq('/requests/10/actions/30/rpm_lint') }
    end
  end
end
