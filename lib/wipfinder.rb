require 'git'
require 'find'
require 'pry'
require 'logger'
require 'coque'

module WipFinder
  def self.find_wips(base_dir)
    git_repos = Dir.glob("#{base_dir}/**/.git")[0..30]

    puts "Found #{git_repos.size} repos in #{base_dir}"
    dirty = git_repos.map do |git_dir|
      project_dir = File.expand_path("..", git_dir)
      check_repo(project_dir)
    end.select do |status|
      status.missing_remote? || status.dirty?
    end

    puts "Found #{dirty.size} repos with potential push issues"
    dirty.each do |s|
      puts s.report
    end
  end

  BASE_REMOTE = "origin"
  BASE_BRANCH = "master"
  BASE = "origin/master"

  def self.refresh(git)
    git.fetch
  rescue Git::GitExecuteError => ex
    if ex.message.include?("Repository not found")
      STDERR.puts("ERROR: Git repo at #{git.repo.path} could not be fetched because its remote does not exist.")
    end
  end

  def self.check_repo(path)
    # uncommitted files
    # stashes
    # unpushed + unmerged branches
    # TODO: default branch dynamic
    puts "Checking repo #{path}"

    git = Git.open(path)

    remote_ok = refresh(git)
    if !remote_ok
      return Status.new(path, false)
    end

    remote_branches = git.branches.remote

    unpushed = git.branches.local.reject do |b|
      merged = Coque['git', '--git-dir', File.join(path, '.git'),
                     'merge-base', BASE, b.name].to_a
      branch_head = b.gcommit.sha
      is_merged_to_master = merged.size == 1 && merged[0] == branch_head
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
      size > 1
    end.to_h

    Status.new(
      path,
      true,
      git.status.untracked.size,
      git.status.changed.size,
      git.status.deleted.size,
      unpushed
    )
  end

  class Status < Struct.new(:path, :has_remote, :untracked, :changed, :deleted, :unpushed)
    def missing_remote?
      !has_remote
    end

    def dirty?
      untracked > 1 || changed > 1 || deleted > 1 || unpushed.size > 1
    end

    def report
      if missing_remote?
        "Git repo at #{path} has no live remote -- it may be local only or its remotes may have been deleted."
      else
        ["Git repo at #{path} is dirty",
         "untracked files: #{untracked}",
         "changed files: #{changed}",
         "deleted files: #{deleted}",
         "unpushed branches:",
         unpushed.map { |b, count| "    #{b} - #{count} commits"}.join("\n")
        ].join("\n")
      end
    end
  end
end
