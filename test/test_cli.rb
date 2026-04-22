# frozen_string_literal: true

require_relative './test_helper'

class TestRubyLinkChecker < Minitest::Test

  # The tests for the first two options do not call the checker.

  def test_cli_option_version
    Command.new(
      self,
      __method__,
      options: %w[ --version ],
      exp_stdout: /\d+\.\d+\.\d+/
    ).execute
  end

  def test_cli_option_help
    Command.new(
      self,
      __method__,
      options: %w[ --help ],
      exp_stdout: 'Usage: bin/ruby_link_checker [options]',
      ).execute
  end

  # The tests for the options below use option --no-op
  # to cause the checker and its reporter to print options.
  # The tests verify only that the options are passed correctly,
  # not that the checker uses them well or wisely;
  # that's a job for other tests.

  def test_cli_option_no_op
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'no_op: true'
    ).execute
  end

  def test_cli_option_source_master
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'source: master'
    ).execute
  end

  def test_cli_option_source_revision
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --source=4.0 ],
      exp_stdout: 'source: 4.0'
    ).execute
  end

  def test_cli_option_source_bad
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --source=nosuch ],
      exp_stderr: '404',
      exp_status: 1,
    ).execute
  end

  def test_cli_option_report_only
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'report_only: false'
    ).execute
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --report-only ],
      exp_stdout: 'report_only: true'
    ).execute
  end

  def test_cli_option_open_report
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'open_report: false'
    ).execute
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --open-report ],
      exp_stdout: 'open_report: true'
    ).execute
  end

  def test_cli_option_verbosity_default
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'verbosity: moderate'
    ).execute
  end

  def test_cli_option_verbosity_quiet
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --verbosity=quiet],
      exp_stdout: 'verbosity: quiet'
    ).execute
  end

  def test_cli_option_verbosity_minimal
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --verbosity=minimal],
      exp_stdout: 'verbosity: minimal'
    ).execute
  end

  def test_cli_option_verbosity_moderate
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'verbosity: moderate'
    ).execute
  end

  def test_cli_option_verbosity_debug
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --verbosity=debug ],
      exp_stdout: 'verbosity: debug'
    ).execute
  end

  def test_cli_option_verbosity_bad
    command = Command.new(
      self,
      __method__,
      options: %w[ --no-op --verbosity=nosuch ],
      exp_status: 1,
    )
    command.execute
    %w[ Error --verbosity nosuch ArgumentError].each do |s|
      command.act_stderr.match(s)
    end
  end

  def test_cli_option_legal
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'legal: false'
    ).execute
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --legal ],
      exp_stdout: 'legal: true'
    ).execute
  end

  def test_cli_option_news
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'news: false'
    ).execute
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --news ],
      exp_stdout: 'news: true'
    ).execute
  end

  def test_cli_option_github_lines
    Command.new(
      self,
      __method__,
      options: %w[ --no-op ],
      exp_stdout: 'github_lines: false'
    ).execute
    Command.new(
      self,
      __method__,
      options: %w[ --no-op --github-lines ],
      exp_stdout: 'github_lines: true'
    ).execute
  end

end
