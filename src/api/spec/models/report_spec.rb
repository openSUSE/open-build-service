require 'rails_helper'

RSpec.describe Report, type: :model do
  subject { Report.create(failure_message: 'something happened') }

  it "sets 'succeeded' to false when there is a failure message" do
    expect(subject.succeeded).to be(false)
  end
end
