#!/usr/bin/ruby
# frozen_string_literal: true

require 'optparse'

class CreateDiffendIoLinks
  def initialize
    parse_arguments
    @gem_version_change_infos = {}

    added_gems = receive_changed_gem_file_names(diff_filter_value: 'A')
    removed_gems = receive_changed_gem_file_names(diff_filter_value: 'D')

    gather_gem_version_change_infos(gem_file_names: added_gems, mode: 'added_version')
    gather_gem_version_change_infos(gem_file_names: removed_gems, mode: 'deleted_version')

    markdown_diffend_links = create_markdown_diffend_io_links

    unless markdown_diffend_links.empty?
      comment_text = "Please see the links listed bellow to review the changes applied to the gems:\n"
      comment_text += markdown_diffend_links.join("\n")
      create_artifacts(comment_text: comment_text)
    end
  end

  private

  def parse_arguments
    opt_parser = OptionParser.new do |parser|
      parser.banner = 'Usage: create_diffend_io_links.rb [options]'
      parser.on('-b', '--gh_base_ref GITHUB_BASE_REF', 'specify the base ref') { |gh_base_ref| @github_base_ref = gh_base_ref }
      parser.on('-s', '--gh_sha GITHUB_SHA', 'specify the commit sha') { |gh_sha| @github_sha = gh_sha }
      parser.on('-h', '--help', 'Print this help') do
        puts parser
        exit
      end
    end
    opt_parser.parse!(ARGV)
  end

  def receive_changed_gem_file_names(diff_filter_value:)
    files_from_git_diff = `git diff-tree -r --name-only --diff-filter=#{diff_filter_value} origin/#{@github_base_ref} #{@github_sha}`.split("\n")
    filter_gem_files_from_diff_paths(filepaths: files_from_git_diff)
  end

  def filter_gem_files_from_diff_paths(filepaths:)
    filepaths.filter_map do |filepath|
      File.basename(filepath, '.gem') if File.extname(filepath) == '.gem'
    end
  end

  # { gem_name: { added_version: '0.1.2', deleted_version: '0.1.1' }, ...}
  def gather_gem_version_change_infos(gem_file_names:, mode:)
    gem_file_names.each_with_index do |gem_file, index|
      gem = gem_file.split('-')

      version_number = gem.last.scan(/\d+/).join('.')
      gem.pop()
      gem_name = gem.join('-')

      if @gem_version_change_infos["#{gem_name}"].nil?
        @gem_version_change_infos["#{gem_name}"] = { "#{mode}": "#{version_number}" }
      else
        @gem_version_change_infos["#{gem_name}"].merge!("#{mode}": "#{version_number}")
      end
    end
  end

  def create_markdown_diffend_io_links
    @gem_version_change_infos.select { |k,v| version_update_and_diff_available?(added_version: v[:added_version], deleted_version: v[:deleted_version]) }
      .map do |gem_name, version_info|
        diffend_io_link = "https://my.diffend.io/gems/#{gem_name}/#{version_info[:added_version]}/#{version_info[:deleted_version]}"
        "[#{gem_name} #{version_info[:deleted_version]} -> #{version_info[:added_version]}](#{diffend_io_link})"
    end
  end

  # Diffend.io only has diffs available for version updates, not for downgrades.
  # We also have to make sure that it's an update of a gem, not a removal or addition.
  def version_update_and_diff_available?(added_version:, deleted_version:)
    return false if added_version.nil? || deleted_version.nil?
    return false unless Gem::Version.new(added_version) > Gem::Version.new(deleted_version)

    true
  end

  def create_artifacts(comment_text:)
    Dir.mkdir('artifacts')
    File.write('artifacts/comment_text.txt', comment_text)
  end
end

CreateDiffendIoLinks.new
