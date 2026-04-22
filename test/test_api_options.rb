# frozen_string_literal: true

require_relative './test_helper'

class TestRubyLinkChecker < Minitest::Test

  def test_boolean_options
    %i[open_report report_only github_lines legal news ].each do |option|
      [true, false].each do |value|
        options = {option => value, :no_op => true}
        assert RubyLinkChecker.new(options: options)
      end
      value = 'foo'
      x = assert_raises(ArgumentError) do
        options = {option => value, :no_op => true}
        RubyLinkChecker.new(options: options)
      end
      assert_match("Error: --#{option} must be one of: true, false; not #{value}", x.message)
    end
  end

  def test_verbosity_options
    option = :verbosity
    %w[quiet minimal moderate debug].each do |value|
      options = {option => value, :no_op => true}
      assert RubyLinkChecker.new(options: options)
    end
    value = 'foo'
    x = assert_raises(ArgumentError) do
      options = {option => value, :no_op => true}
      RubyLinkChecker.new(options: options)
    end
    assert_match("Error: --verbosity must be one of: quiet, minimal, moderate, debug; not #{value}", x.message)
  end

  def test_source_option_nil
    option = :source
    options = {option => nil, :no_op => true}
    assert RubyLinkChecker.new(options: options)
  end

  def test_source_option_master
    option = :source
    options = {option => 'master', :no_op => true}
    assert RubyLinkChecker.new(options: options)
  end

  def test_source_option_branch
    option = :source
    options = {option => '4.0', :no_op => true}
    assert RubyLinkChecker.new(options: options)
  end

  def test_source_option_base_url
    option = :source
    options = {option => 'https://docs.ruby-lang.org/en/', :no_op => true}
    assert RubyLinkChecker.new(options: options)
  end

  def test_source_option_file
    option = :source
    options = {option => 'README.md', :no_op => true}
    assert RubyLinkChecker.new(options: options)
  end

  def test_source_option_nosuch_url
    option = :source
    url = 'https://docs.ruby-lang.org/en/Nosuch.html'
    x = assert_raises(HTTPResponseException) do
      options = {option => url, :no_op => true}
      RubyLinkChecker.new(options: options)
    end
    exp_description = "Response code (404) for URI #{url}"
    assert_match(exp_description, x.description)
  end

  def test_source_option_nosuch
    option = :source
    value = 'nosuch'
    x = assert_raises(HTTPResponseException) do
      options = {option => value, :no_op => true}
      RubyLinkChecker.new(options: options)
    end
    tried_url = File.join(RubyLinkChecker::BASE_URL, value)
    exp_description = "Response code (404) for URI #{tried_url}"
    assert_match(exp_description, x.description)
  end

end
