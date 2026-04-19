# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require_relative '../lib/ruby_link_checker'
require_relative '../lib/ruby_link_checker/version'

class TestRubyLinkChecker < Minitest::Test

  # Class to execute a command.
  class Command

    attr_accessor :test,                                  # TestRubyLinkChecker object
                  :method,                                # Name of test method.
                  :options, :arguments,                   # CLI options and arguments.
                  :exp_stdout, :exp_stderr, :exp_status,  # Expected output values.
                  :act_stdout, :act_stderr, :act_status   # Actual output values.

    # Returns a new Command object.
    def initialize(
      test,
      method,
      options: [],
      arguments: [],
      exp_stdout: '',
      exp_stderr: '',
      exp_status: 0)
      self.test = test
      self.method = method.to_s
      self.options = options
      self.arguments = arguments
      self.exp_stdout = exp_stdout
      self.exp_stderr = exp_stderr
      self.exp_status = exp_status
    end

    EXECUTABLE_PATH = 'bin/ruby_link_checker'

    # Executes the command, after which actual values are available.
    def execute
      command = "ruby #{EXECUTABLE_PATH} #{options.join(' ')} #{arguments.join(' ')}"
      self.act_stdout, self.act_stderr, status = Open3.capture3(command)
      test.assert_match(exp_stdout, act_stdout, method + ' stdout')
      test.assert_match(exp_stderr, act_stderr, method + ' stderr')
      self.act_status = status.exitstatus
      test.assert_equal(exp_status, act_status, method + ' status')
    end
  end

end

