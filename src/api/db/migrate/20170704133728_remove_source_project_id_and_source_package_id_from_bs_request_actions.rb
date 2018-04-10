# frozen_string_literal: true

class RemoveSourceProjectIdAndSourcePackageIdFromBsRequestActions < ActiveRecord::Migration[5.1]
  def change
    remove_reference(:bs_request_actions, :source_package, index: true)
    remove_reference(:bs_request_actions, :source_project, index: true)
  end
end
