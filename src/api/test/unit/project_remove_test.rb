# Testing the things that should and shouldn't happen when you remove a Project
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'securerandom'

class ProjectRemoveTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    Backend::Test.start
  end

  def test_destroy_source_revokes_request
    User.current = users(:Iggy)
    branch_package
    create_request

    @package.project.destroy

    @request.reload
    assert_equal :revoked, @request.state
    assert_equal "The source project 'home:#{User.current.login}:branches:Apache' has been removed", @request.comment
    assert_equal 1, HistoryElement::RequestRevoked.where(op_object_id: @request.id).count
  end

  def test_destroy_target_declines_request
    User.current = users(:king)
    project = Project.create(name: 'test_destroy_target_declines_request')
    project.store

    User.current = users(:Iggy)
    other_project = Project.find_by(name: 'home:Iggy')
    other_package = other_project.packages.create(name: 'pack')
    create_request('test_destroy_target_declines_request', 'pack', 'home:Iggy')

    User.current = users(:king)
    project.destroy

    @request.reload
    assert_equal :declined, @request.state
    assert_equal "The target project 'test_destroy_target_declines_request' has been removed", @request.comment
    assert_equal 1, HistoryElement::RequestDeclined.where(op_object_id: @request.id).count

    other_package.destroy
  end

  def test_accept_request_does_not_revoke_request_for_single_package
    User.current = users(:Iggy)
    branch_package
    create_request

    User.current = users(:fred)
    @request.change_state(newstate: 'accepted',
                          force: true,
                          user: 'fred')

    assert_equal :accepted, @request.reload.state
    assert_equal 0, HistoryElement::RequestRevoked.where(op_object_id: @request.id).count

    @package.project.destroy
  end

  def test_accept_request_does_not_revoke_request_for_multiple_packages
    User.current = users(:Iggy)
    branch_package
    project = Project.find_by(name: 'home:Iggy:branches:Apache')
    project.packages.create!(name: 'pack')
    create_request

    User.current = users(:fred)
    @request.change_state(newstate: 'accepted',
                          force: true,
                          user: 'fred')

    assert_equal :accepted, @request.reload.state
    assert_equal 0, HistoryElement::RequestRevoked.where(op_object_id: @request.id).count

    @package.project.destroy
  end

  def test_review_gets_obsoleted
    review_project = Project.create(name: 'test_review_gets_removed')

    User.current = users(:Iggy)
    branch_package
    create_request
    @request.addreview(by_project: review_project.name)
    @request.reload
    assert_equal :review, @request.state

    assert_equal 1, @request.reviews.count
    assert_equal 1, HistoryElement::RequestReviewAdded.where(op_object_id: @request.id).count
    assert_equal :new, @request.reviews.first.state

    review_project.destroy

    @request.reload
    assert_equal 1, @request.reviews.count
    assert_equal :obsoleted, @request.reviews.first.state

    # request changed to new state
    assert_equal :new, @request.state

    # cleanup
    @package.project.destroy
  end

  private

  # FIXME: A test mixin? Hmmm....
  def branch_package(project = 'Apache', package = 'apache2')
    # Branch a package and change it's contents
    BranchPackage.new(project: project, package: package).branch
    @package = Package.find_by_project_and_name("home:#{User.current.login}:branches:#{project}", package)
    @package.save_file(file: 'whatever', filename: "testfile#{SecureRandom.hex}") # always new file to have changes in the package
  end

  def create_request(project = 'Apache', package = 'apache2', source_project = "home:#{User.current.login}:branches:#{project}")
    # Create a request to submit the changes back
    request = BsRequest.new(state: 'new', description: 'project_remove_test')
    action = BsRequestActionSubmit.new(source_project: source_project,
                                       source_package: package,
                                       target_project: project,
                                       target_package: package,
                                       sourceupdate: 'update')
    request.bs_request_actions << action
    action.bs_request = request
    request.set_add_revision
    request.save!
    @request = request.reload

    # The request should be new
    assert_equal :new, @request.reload.state
  end
end
