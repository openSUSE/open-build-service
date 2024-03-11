RSpec.shared_examples 'a flag table' do
  def enable_flag_field_for(flag_attributes)
    change_flag_field_to(flag_attributes, 'Enable')
  end

  def disable_flag_field_for(flag_attributes)
    change_flag_field_to(flag_attributes, 'Disable')
  end

  # flag_attributes are repository and architecture. Both are used
  # to identify correct field coordinates of the flag table.
  def change_flag_field_to(flag_attributes, to)
    locator = css_locator_for(flag_attributes[:repository], flag_attributes[:architecture])

    subject.find(locator).find('.current_flag_state').hover
    # Workaround: There can be an additional link with
    #             text similar to "Enable Take default (disable)"
    subject.find(locator, text: /#{to}/).first('a').click
    # Wait for request to finish
    subject.find(locator).find(".current_flag_state.icons-#{flag_type}_#{to.downcase}_blue")
  end

  def css_locator_for(repository, architecture)
    row = repo_cols.index(repository) + 1
    col = arch_rows.index(architecture) + 1

    "tr:nth-child(#{row}) td:nth-child(#{col})"
  end

  # default attributes we are going to need to verify flags got updated
  let(:query_attributes) { { repo: nil, architecture_id: nil, flag: flag_type } }

  it 'has correct table headers (arch labels)' do
    # Repository | All | $archs ...
    expect(subject.find('tr:first-child th:nth-child(1)').text).to eq('Repository')
    expect(subject.find('tr:first-child th:nth-child(2)').text).to eq('All')
    architectures.each do |arch|
      pos = architectures.index(arch) + 3
      # There might be delays when rendering the table. Thus including the
      # text entry to the selector.
      subject.find("tr:first-child th:nth-child(#{pos})", text: arch)
    end
  end

  it 'has correct column descriptions (repository labels)' do
    # Repository | All | $repositories ...
    expect(subject.find('tr:nth-child(1) th:first-child').text).to eq('Repository')
    expect(subject.find('tr:nth-child(2) td:first-child').text).to eq('All')
    expect(subject.find('tr:nth-child(3) td:first-child').text).to eq(repository.name)
  end

  it 'toggle flags per repository' do
    query_attributes[:repo] = repository.name

    disable_flag_field_for(repository: repository.name, architecture: 'All')
    expect(project.flags.reload.where(query_attributes.merge(status: :disable))).to exist

    enable_flag_field_for(repository: repository.name, architecture: 'All')
    expect(project.flags.reload.where(query_attributes.merge(status: :enable))).to exist
  end

  it 'toggle flags per arch' do
    query_attributes[:architecture_id] = Architecture.find_by_name('i586')

    disable_flag_field_for(repository: 'All', architecture: 'i586')
    expect(project.flags.reload.where(query_attributes.merge(status: :disable))).to exist

    enable_flag_field_for(repository: 'All', architecture: 'i586')
    expect(project.flags.reload.where(query_attributes.merge(status: :enable))).to exist
  end

  it 'toggle all flags at once' do
    query_attributes[:flag] = flag_type

    disable_flag_field_for(repository: 'All', architecture: 'All')
    expect(project.flags.reload.where(query_attributes.merge(status: :disable))).to exist

    enable_flag_field_for(repository: 'All', architecture: 'All')
    expect(project.flags.reload.where(query_attributes.merge(status: :enable))).to exist
  end

  it 'toggle a single flag' do
    query_attributes.merge!(repo: repository.name, architecture_id: Architecture.find_by_name('x86_64'))

    disable_flag_field_for(repository: repository.name, architecture: 'x86_64')
    expect(project.flags.reload.where(status: 'disable')).to exist

    enable_flag_field_for(repository: repository.name, architecture: 'x86_64')
    expect(project.flags.reload.where(status: 'enable')).to exist
  end
end

RSpec.shared_examples 'tests for sections with flag tables' do
  describe 'flags tables' do
    let(:architectures) { %w[i586 x86_64] }
    let!(:repository) { create(:repository, project: project, architectures: architectures) }
    let(:arch_rows) { %w[Repository All] + architectures }
    let(:repo_cols) { %w[Repository All] + project.repositories.pluck(:name) }

    before do
      login(user)
      visit project_repositories_path(project: project)
    end

    describe '#flag_table_build' do
      subject { find_by_id('flag_table_build') }

      let(:flag_type) { 'build' }

      it_behaves_like 'a flag table'
    end

    describe '#flag_table_publish' do
      subject { find_by_id('flag_table_publish') }

      let(:flag_type) { 'publish' }

      it_behaves_like 'a flag table'
    end

    describe '#flag_table_debuginfo' do
      subject { find_by_id('flag_table_debuginfo') }

      let(:flag_type) { 'debuginfo' }

      before do
        # Default status would be 'disabled'
        create(:debuginfo_flag, project: project)
        visit project_repositories_path(project: project)
      end

      it_behaves_like 'a flag table'
    end

    describe '#flag_table_useforbuild' do
      subject { find_by_id('flag_table_useforbuild') }

      let(:flag_type) { 'useforbuild' }

      it_behaves_like 'a flag table'
    end
  end
end
