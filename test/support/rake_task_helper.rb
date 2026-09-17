# frozen_string_literal: true

require "rake"

# Invoking a rake task from inside a test, without the two traps.
#
# 1. NOT a child process. The first version of these tests shelled out to
#    `bin/rails blog:stuck`, and the task reported nothing — because the records
#    the test had created lived in an uncommitted transaction the child could not
#    see. A green assertion and an invisible database look identical from
#    outside. So the task runs here, in the transaction.
# 2. `abort` raises SystemExit rather than setting an exit status, so it is
#    translated back into the code a shell would have seen. Tasks in this app use
#    `abort` deliberately (they run under `kamal app exec`, where exiting 0 after
#    doing nothing reads as success), and that behaviour is worth asserting.
#
# Rails.application.load_tasks is memoized per process: calling it twice reloads
# railties' own rake files and prints "already initialized constant
# STATS_DIRECTORIES" warnings over the test output.
module RakeTaskHelper
  def self.load_tasks_once
    return if @loaded

    Rails.application.load_tasks
    @loaded = true
  end

  # Returns [combined stdout+stderr, exit code].
  def invoke_task(name)
    RakeTaskHelper.load_tasks_once
    task = Rake::Task[name]
    task.reenable

    captured = StringIO.new
    original_stdout, original_stderr = $stdout, $stderr
    $stdout = $stderr = captured
    code = 0
    begin
      task.invoke
    rescue SystemExit => e
      code = e.status
    ensure
      $stdout, $stderr = original_stdout, original_stderr
    end

    [ captured.string, code ]
  end

  def rake_task_defined?(name)
    RakeTaskHelper.load_tasks_once
    Rake::Task.task_defined?(name)
  end
end
