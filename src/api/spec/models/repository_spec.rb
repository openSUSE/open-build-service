require "rails_helper"

RSpec.describe Repository do
  describe "validations" do
    it { is_expected.to validate_length_of(:name).is_at_least(1).is_at_most(200) }
    it { is_expected.to validate_presence_of(:db_project_id) }
    it "validates uniqueness of name" do
      repository = create(:repository)
      expect(repository).to validate_uniqueness_of(:name).
                              scoped_to(:db_project_id, :remote_project_name).
                              with_message("#{repository.name} is already used by a repository of this project.")
    end
    it { should_not allow_value("_foo").for(:name) }
    it { should_not allow_value("f:oo").for(:name) }
    it { should_not allow_value("f/oo").for(:name) }
    it { should_not allow_value("f\noo").for(:name) }
    it { should allow_value("fOO_-§$&!#+~()=?\\\"").for(:name) }
    it { should allow_value("f").for(:name) }
  end
end
