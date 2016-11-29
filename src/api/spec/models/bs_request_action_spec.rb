require 'rails_helper'

RSpec.describe BsRequestAction do
  it { should belong_to(:bs_request).touch(true) }
end
