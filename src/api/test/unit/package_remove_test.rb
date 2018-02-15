# Testing the things that should and shouldn't happen when you remove a Package
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class PackageRemoveTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    Backend::Test.start
  end

  def test_destroy_source_revokes_request
    User.current = users(:Iggy)
    branch_package
    create_request

    @package.destroy

    @request.reload
    assert_equal :revoked, @request.state
    assert_equal "The source package 'apache2' has been removed", @request.comment
    assert_equal 1, HistoryElement::RequestRevoked.where(op_object_id: @request.id).count
  end

  def test_review_gets_obsoleted
    project = Project.find_by(name: 'Apache')
    review_package = project.packages.create(name: 'test_review_gets_removed')

    User.current = users(:Iggy)
    branch_package
    create_request
    @request.addreview(by_project: review_package.project.name, by_package: review_package.name)
    @request.reload
    assert_equal :review, @request.state

    assert_equal 1, @request.reviews.count
    assert_equal 1, HistoryElement::RequestReviewAdded.where(op_object_id: @request.id).count
    assert_equal :new, @request.reviews.first.state

    review_package.destroy

    @request.reload
    assert_equal 1, @request.reviews.count
    assert_equal 1, HistoryElement::RequestReviewAdded.where(op_object_id: @request.id).count
    assert_equal :obsoleted, @request.reviews.first.state

    # request changed to new state
    assert_equal :new, @request.state
  end

  def test_destroy_target_declines_request
    User.current = users(:king)
    project = Project.create(name: 'test_destroy_target_declines_request')
    project.store
    project.packages.create(name: 'pack')

    User.current = users(:Iggy)
    branch_package('test_destroy_target_declines_request', 'pack')
    create_request('test_destroy_target_declines_request', 'pack')

    User.current = users(:king)
    Package.find_by_project_and_name('test_destroy_target_declines_request', 'pack').destroy

    @request.reload
    assert_equal :declined, @request.state
    assert_equal "The target package 'pack' has been removed", @request.comment
    assert_equal 1, HistoryElement::RequestDeclined.where(op_object_id: @request.id).count

    @package.project.destroy
  end

  private

  def branch_package(project = 'Apache', package = 'apache2')
    # Branch a package and change it's contents
    BranchPackage.new(project: project, package: package).branch
    @package = Package.find_by_project_and_name("home:#{User.current.login}:branches:#{project}", package)
    @package.save_file(file: 'whatever', filename: "testfile#{Time.now.sec}") # always new file to have changes in the package
  end

  def create_request(project = 'Apache', package = 'apache2')
    # Create a request to submit the changes back
    request = BsRequest.new(state: 'new', description: 'package_remove_test')
    action = BsRequestActionSubmit.new(source_project: "home:#{User.current.login}:branches:#{project}",
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
