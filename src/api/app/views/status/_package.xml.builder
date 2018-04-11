# frozen_string_literal: true

builder.package(package.header) do
  package.fails.each do |repository, _architecture, time, md5|
    builder.failure(repo: repository, time: time, srcmd5: md5)
  end

  if package.develpack
    builder.develpack(proj: package.develpack.project, pack: package.develpack.name) do
      render(partial: 'package', locals: { builder: builder, package: package.develpack })
    end
  end

  if package.persons.any?
    builder.persons do
      package.persons.each do |user_id, role|
        builder.person(userid: user_id, role: role)
      end
    end
  end

  if package.groups.any?
    builder.groups do
      package.groups.each do |group_id, role|
        builder.group(groupid: group_id, role: role)
      end
    end
  end

  builder.error(package.error) if package.error
  builder.link(project: package.links_to.project, package: package.links_to.name) if package.links_to
end
