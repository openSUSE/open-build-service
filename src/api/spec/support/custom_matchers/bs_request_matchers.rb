require 'rspec/expectations'

RSpec::Matchers.define :have_a_submit_request_for do |expected|
  match do |actual_bs_request|
    actual_bs_request.
      joins(:bs_request_actions).
      where("bs_request_actions.type=?", "submit").
      where("bs_request_actions.target_project=?", expected[:target_package].project.name).
      where("bs_request_actions.target_package=?", expected[:target_package].name).
      where("bs_request_actions.source_project=?", expected[:source_package].project.name).
      where("bs_request_actions.source_package=?", expected[:source_package].name).
      exists?
  end
end
