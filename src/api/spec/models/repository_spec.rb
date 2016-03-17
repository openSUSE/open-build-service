require "rails_helper"

RSpec.describe Repository do
  describe "validations" do
    it { is_expected.to validate_length_of(:name).is_at_least(1).is_at_most(200) }
    it { should_not allow_value("_foo").for(:name) }
    it { should_not allow_value("f:oo").for(:name) }
    it { should_not allow_value("f/oo").for(:name) }
    it { should_not allow_value("f\noo").for(:name) }
    it { should allow_value("fOO_-§$&!#+~()=?\\\"").for(:name) }
  end
end
