require 'rails_helper'

RSpec.describe Review do
  it { should belong_to(:bs_request).touch(true) }
end
