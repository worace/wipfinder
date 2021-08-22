require 'git'
require 'find'
require 'pry'
require 'logger'
require 'coque'

module WipFinder
  def self.find_wips(base_dir, no_fetch)
    git_repos = Dir.glob("#{base_dir}/**/.git")

    puts "Found #{git_repos.size} repos in #{base_dir}"
    dirty = git_repos.lazy.map do |git_dir|
      project_dir = File.expand_path("..", git_dir)
      puts "check project dir #{project_dir}"
      check_repo(project_dir, no_fetch)
    end.select do |status|
      status.missing_remote? || status.dirty?
    end.map do |s|
      puts '------------------------------------'
      puts s.report
      s
    end

    puts "Found #{dirty.size} dirty projects."
    dirty.each do |s|
      puts s.path
    end
  end

  BASE_REMOTE = "origin"
  BASE_OPTIONS = ['main', 'master', 'develop']

  def self.refresh(git)
    git.fetch
  rescue Git::GitExecuteError => ex
    if ex.message.include?("Repository not found")
      STDERR.puts("ERROR: Git repo at #{git.repo.path} could not be fetched because its remote does not exist.")
    end
  end

  def self.check_repo(path, no_fetch)
    # uncommitted files
    # stashes
    # unpushed + unmerged branches
    # TODO: default branch dynamic
    puts "Checking repo #{path}"

    git_cmd = Coque['git', '--git-dir', File.join(path, '.git')]

    begin
      base = git_cmd['symbolic-ref', '--short', "refs/remotes/#{BASE_REMOTE}/HEAD"].to_a![0]
    rescue
      STDERR.puts("WARNING: Could not determine the base branch for #{path}, defaulting to 'master'")
      STDERR.puts("You may want to configure the base branch for this repo by checking out the desired branch and running:")
      STDERR.puts("    git remote set-head origin -a")
      base = 'master'
    end
    puts "Remote base is #{base}"

    git = Git.open(path)

    unless no_fetch
      remote_ok = refresh(git)
      if !remote_ok
        return Status.new(path, false)
      end
    end

    remote_branches = git.branches.remote

    unpushed = git.branches.local.reject do |b|
      merged = git_cmd['merge-base', base, b.name].to_a
      branch_head = b.gcommit.sha
      merged.size == 1 && merged[0] == branch_head
    end.map do |b|
      begin
        if remote_branch = remote_branches.find{|r| r.name == b.name}
          # get the distance between local and remote copy
          [b.name, git.log.between("#{remote_branch.remote.name}/#{b.name}", b.name).size]
        else
          [b.name, 1]
        end
      rescue
        binding.pry
      end
    end.select do |b, size|
      size > 0
    end.to_h


    s = Status.new(
      path,
      true,
      git.status.untracked.size,
      git.status.changed.size,
      git.status.deleted.size,
      unpushed
    )
    s
  end

  class Status < Struct.new(:path, :has_remote, :untracked, :changed, :deleted, :unpushed)
    def missing_remote?
      !has_remote
    end

    def dirty?
      untracked > 0 || changed > 0 || deleted > 0 || unpushed.size > 0
    end

    def report
      if missing_remote?
        "Git repo at #{path} has no live remote -- it may be local only or its remotes may have been deleted."
      else
        ["Git repo at #{path} is dirty",
         "  - untracked files: #{untracked}",
         "  - changed files: #{changed}",
         "  - deleted files: #{deleted}",
         "  - unpushed branches:",
         unpushed.map { |b, count| "      #{b} - #{count} commits"}.join("\n")
        ].join("\n")
      end
    end
  end
end
