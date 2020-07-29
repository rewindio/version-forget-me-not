# frozen_string_literal: true

require_relative 'github_config'

# Fetch and check the version
class Action
  attr_reader :client, :repo, :pull_number, :head_branch, :base_branch

  SEMVER_VERSION =
    /["'](0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?["']/.freeze # rubocop:disable Layout/LineLength

  def initialize(config)
    @client = config.client
    @repo = config.event_payload['repository']['full_name']
    config_pr = config.event_payload['pull_request']
    @pull_number = config_pr['number']
    @head_branch = config_pr['head']['ref']
    @base_branch = config_pr['base']['ref']
  end

  def version_changed?
    version_file_changed?(pull_number) && version_increased?(branch_name: head_branch, trunk_name: base_branch)
  end

  def version_file_changed?(pull_number)
    file_changed = client.pull_request_files(repo, pull_number)
    puts "file changes for PR #{pull_number}: #{file_changed}"
    file_changed.include?(ENV['VERSION_FILE_PATH'])
  end

  def version_increased?(branch_name:, trunk_name: 'master')
    branch_version = fetch_version(ref: branch_name)
    trunk_version = fetch_version(ref: trunk_name)
    puts "branch version: #{branch_version}"
    puts "trunk version: #{trunk_version}"
    branch_version > trunk_version
  end

  private

  def fetch_version(ref:)
    content = client.contents(repo, path: ENV['VERSION_FILE_PATH'], query: { ref: ref })
    version = content.match(SEMVER_VERSION)[0].gsub(/\'|\"/, '')
    Gem::Version.new(version)
  end
end

action = Action.new(GithubConfig.new)
puts "Version Changed: #{action.version_changed?}"
