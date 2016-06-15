RSpec.shared_examples "a flag table" do
  scenario "has correct table headers" do
    # Repository | All | $archs ...
    expect(subject.find("tr:first-child th:nth-child(1)").text).to eq("Repository")
    expect(subject.find("tr:first-child th:nth-child(2)").text).to eq("All")
    architectures.each do |arch|
      pos = architectures.index(arch) + 3
      expect(subject.find("tr:first-child th:nth-child(#{pos})").text).to eq(arch)
    end
  end
end

RSpec.shared_examples "tests for sections with flag tables" do
  describe "flags tables" do
    let(:architectures) { ["i586", "x86_64"] }
    let!(:repository) { create(:repository, project: project, architectures: architectures) }

    before do
      login(user)
      visit project_repositories_path(project: project)
    end

    describe "#flag_table_build" do
      subject { find("#flag_table_build") }
      it_behaves_like "a flag table"
    end

    describe "#flag_table_publish" do
      subject { find("#flag_table_publish") }
      it_behaves_like "a flag table"
    end

    describe "#flag_table_debuginfo" do
      subject { find("#flag_table_debuginfo") }
      it_behaves_like "a flag table"
    end

    describe "#flag_table_useforbuild" do
      subject { find("#flag_table_useforbuild") }
      it_behaves_like "a flag table"
    end
  end
end
