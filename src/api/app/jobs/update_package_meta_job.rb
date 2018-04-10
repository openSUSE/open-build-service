# frozen_string_literal: true

class UpdatePackageMetaJob < ApplicationJob
  # NOTE: Its important that this job run in queue 'default' in order to avoid concurrency
  queue_as :default

  # FIXME: find out what the difference is between calling the backend and asking the database.
  # On first glance this looks like BackendPackage.links. Is it?
  def scan_links
    names = Package.distinct.order(:name).pluck(:name)
    until names.empty?
      answer = Xmlhash.parse(Backend::Api::Search.packages_with_link(names.slice!(0, 30)))
      answer.elements('package') do |p|
        pkg = Package.find_by_project_and_name(p['project'], p['name'])
        # if there is a linkinfo for a package not in database, there can not be a linked_package either
        next unless pkg
        pkg.update_if_dirty
      end
    end
  end

  def perform
    # first we scan the links so that commits happening
    # while the delayed job runs can update our work
    scan_links

    # delete all BackendPackages of patchinfo Packages that are not links
    BackendPackage.not_links.joins(package: :package_kinds).where(package_kinds: { kind: :patchinfo }).delete_all

    BackendPackage.refresh_dirty
  end
end
