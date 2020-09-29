RSpec.shared_examples 'bootstrap a flag table' do
  def enable_flag_field_for(flag_attributes)
    change_flag_field_to(flag_attributes, 'Enable', '.fa-check')
  end

  def disable_flag_field_for(flag_attributes)
    change_flag_field_to(flag_attributes, 'Disable', '.fa-ban')
  end

  def change_flag_field_to(flag_attributes, state, icon)
    locator = css_locator_for(flag_attributes[:repository], flag_attributes[:architecture])

    subject.find(locator).find('.current_flag_state').click
    within('.popover') do
      click_link(state)
    end
    subject.find(locator).find(icon)
  end

  def remove_flag_field_for(flag_attributes)
    locator = css_locator_for(flag_attributes[:repository], flag_attributes[:architecture])

    subject.find(locator).find('.current_flag_state').click
    within('.popover') do
      click_link('Take default (enable)')
    end
    subject.find(locator).find('.fa-check')
  end

  def css_locator_for(repository, architecture)
    row = repo_cols.index(repository)
    col = arch_rows.index(architecture) + 1

    "tr:nth-child(#{row}) td:nth-child(#{col})"
  end

  let(:query_attributes) { { repo: nil, architecture_id: nil, flag: flag_type } }

  scenario 'has correct table headers (arch labels)' do
    expect(subject.find('tr:first-child th:nth-child(1)').text).to eq('Repository')
    expect(subject.find('tr:first-child th:nth-child(2)').text).to eq('All')
    architectures.each do |arch|
      pos = architectures.index(arch) + 3
      subject.find("tr:first-child th:nth-child(#{pos})", text: arch)
    end
  end

  scenario 'has correct column descriptions (repository labels)' do
    expect(subject.find('thead th:first-child').text).to eq('Repository')
    expect(subject.find('tr:nth-child(1) td:first-child').text).to eq('All')
    expect(subject.find('tr:nth-child(2) td:first-child').text).to eq(repository.name)
  end

  scenario 'toggle flags per repository' do
    query_attributes[:repo] = repository.name

    disable_flag_field_for(repository: repository.name, architecture: 'All')
    expect(project.flags.where(query_attributes.merge(status: :disable))).to exist

    enable_flag_field_for(repository: repository.name, architecture: 'All')
    expect(project.flags.where(query_attributes.merge(status: :enable))).to exist
  end

  scenario 'toggle flags per arch' do
    query_attributes[:architecture_id] = Architecture.find_by_name('i586')

    disable_flag_field_for(repository: 'All', architecture: 'i586')
    expect(project.flags.where(query_attributes.merge(status: :disable))).to exist

    enable_flag_field_for(repository: 'All', architecture: 'i586')
    expect(project.flags.where(query_attributes.merge(status: :enable))).to exist
  end

  scenario 'toggle all flags at once' do
    query_attributes[:flag] = flag_type

    disable_flag_field_for(repository: 'All', architecture: 'All')
    expect(project.flags.where(query_attributes).pluck(:status)).to contain_exactly('disable')

    enable_flag_field_for(repository: 'All', architecture: 'All')
    expect(project.flags.where(query_attributes).pluck(:status)).to contain_exactly('enable')
  end

  scenario 'toggle a single flag' do
    query_attributes.merge!(repo: repository.name, architecture_id: Architecture.find_by_name('x86_64'))

    disable_flag_field_for(repository: repository.name, architecture: 'x86_64')
    expect(project.flags.where(query_attributes).pluck(:status)).to contain_exactly('disable')

    enable_flag_field_for(repository: repository.name, architecture: 'x86_64')
    expect(project.flags.where(query_attributes).pluck(:status)).to contain_exactly('enable')

    remove_flag_field_for(repository: repository.name, architecture: 'x86_64')
    expect(project.flags.where(query_attributes).pluck(:status)).to be_empty
  end
end

RSpec.shared_examples 'bootstrap tests for sections with flag tables' do
  describe 'flags tables' do
    let(:architectures) { ['i586', 'x86_64'] }
    let!(:repository) { create(:repository, project: project, architectures: architectures) }
    let(:arch_rows) { ['Repository', 'All'] + architectures }
    let(:repo_cols) { ['Repository', 'All'] + project.repositories.pluck(:name) }

    before do
      login(user)
      visit project_repositories_path(project: project)
    end

    describe '#flag_table_build' do
      let(:flag_type) { 'build' }

      subject { find('#flag_table_build') }

      it_behaves_like 'bootstrap a flag table'
    end

    describe '#flag_table_publish' do
      let(:flag_type) { 'publish' }

      subject { find('#flag_table_publish') }

      it_behaves_like 'bootstrap a flag table'
    end

    describe '#flag_table_debuginfo' do
      let(:flag_type) { 'debuginfo' }

      before do
        # Default status would be 'disabled'
        create(:debuginfo_flag, project: project)
        visit project_repositories_path(project: project)
      end

      subject { find('#flag_table_debuginfo') }

      it_behaves_like 'bootstrap a flag table'
    end

    describe '#flag_table_useforbuild' do
      let(:flag_type) { 'useforbuild' }

      subject { find('#flag_table_useforbuild') }

      it_behaves_like 'bootstrap a flag table'
    end
  end
end
