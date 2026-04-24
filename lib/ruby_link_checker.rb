
require 'net/http'
require 'json'
require 'json/add/time'
require 'fileutils'
require 'pathname'

require_relative 'page'
require_relative 'link'
require_relative 'exception'
require_relative 'report'

# A class to check links on pages in the Ruby documentation
# at the given source.
# TODO:
# - Fix verbosity: stdout, levels.
# - RubyLinkChecker:
#   - Page getter: fetch from web (given URL) or filetree (given dirpath);
#     accept as CLI option or via ENV.
#   - Other options via ENV?
#   - Initialization file?
# - Report:
#   - Change "verify" to "check" both in doc strings and in method names.
#   - Change "json" to "stash" in doc strings.
#   - Report target, CLI options, ENV values.
#   - Re-structure code, and comment.
#   - Open report in browser (all platforms).
#   - Separate reports:
#     - Main report; links to others:
#       - Onsite pages.
#       - Breaks by page.
#       - Offsite pages.
# - Performance optimizations:
#   - Profile.
#   - On-site page: gather ids only if fragments cited.
#   - Off-site page: GET and gather ids only if fragments cited;
#     otherwise, just HEAD.
#   - Make a unified links list, to only check a link once.
#   - Don't use JSON addition for Time; write and read as string.
class RubyLinkChecker

  SCHEME_LIST = URI.scheme_list.keys.map {|scheme| scheme.downcase}
  SCHEME_REGEXP = Regexp.new('^(' + SCHEME_LIST.join('|') + ')')
  DEFAULT_OPTIONS = {
    source: 'master',
    report_only: false,
    open_report: false,
    github_lines: false,
    legal: false,
    news: false,
    verbosity: 'moderate',
    no_op: false,
    from_stash: false
  }

  # URL for documentation base page.
  BASE_URL = 'https://docs.ruby-lang.org/en'

  attr_accessor :paths, :times, :options, :source_type, :source, :progress_level

  # Return a new RubyLinkChecker object.
  def initialize(paths = {}, times = {}, options = DEFAULT_OPTIONS)
    # Options keys from CLI are already symbols;
    # those from JSON are strings, so transform to symbols.
    transformed_options = options.transform_keys {|old_key| old_key.to_sym }
    self.options = DEFAULT_OPTIONS.merge(transformed_options)
    check_options(self.options)
    if self.options[:no_op]
      puts 'Options:'
      self.options.each_pair do |key, value|
        puts "  #{key}: #{value}"
      end
      return
    end
    self.progress_level = %w[quiet minimal moderate debug].index(self.options[:verbosity])
    p self.progress_level
    message = 'Created RubyLinkChecker'
    if self.options[:from_stash]
      message += ' from stash.'
    else
      message += ' from source.'
    end
    progress(1, message)
    self.paths = paths
    self.times = times
    self.source_type, self.source = get_source(self.options[:source])
    if self.options[:no_op]
      progress(1, "No-op competed.")
      exit
    end
    create_stash unless self.options[:report_only]
    report_filepath = Report.new.create_report(self, options)
    if self.options[:open_report]
       command = "start #{report_filepath}"
       system(command)
    end
  end

  def get_source(source_option)
    case
    when source_option.nil?
      [:web, File.join(RubyLinkChecker::BASE_URL, 'master', 'index.html')]
    when source_option.start_with?('http')
      [:web, source_option]
    when File.file?(source_option)
      [:file, source_option]
    else
      [:web, File.join(RubyLinkChecker::BASE_URL, source_option)]
    end
  end

  def create_stash
    progress(1, 'Creating stash.')
    time = Time.now
    timestamp = time.strftime(Report::TIME_FORMAT)
    times['start'] = time
    # Seed paths queue with base url.
    paths_queue = ['']
    # Work on the queued pages.
    until paths_queue.empty?
      # Take the next queued page; skip if already done.
      path = paths_queue.shift
      next if paths[path]
      # New page.
      page = Page.new(source_type, source, path)
      progress(2, "%4.4d queued:  Fetching \"%s\"" % [paths_queue.size, path])
      page.check_page
      paths[path] = page
      # Queue any new paths.
      page.links.each do |link|
        href = link.href
        next if href.start_with?('#')
        _path = href.sub(%r[^\./], '')
        _path, _ = _path.split('#')
        dirname = link.dirname
        if RubyLinkChecker.onsite?(_path) && dirname != '.'
          _path = File.join(dirname, _path)
        end
        # Pathname.cleanpath does not handle HTTP schemes well.
        _path = Pathname.new(_path).cleanpath.to_s if RubyLinkChecker.onsite?(_path)
        # Skip if already done or already queued.
        next if paths.include?(_path)
        next if paths_queue.include?(_path)
        # Queue it.
        progress(2, "%4.4d queued:  Queueing \"%s\"" % [paths_queue.size, _path])
        paths_queue.push(_path)
      end
    end
    times['end'] = Time.now
    options[:report_only] = true
    options[:from_stash] = true
    json = JSON.pretty_generate(self)
    dirpath = File.join('./ruby_link_checker', timestamp)
    FileUtils.mkdir_p(dirpath)
    filename = 'stash.json'
    filepath = File.join(dirpath, filename)
    File.write(filepath, json)
    progress(1, "Stash created at #{filepath}")
  end

  # Returns whether the path is onsite.
  def self.onsite?(path)
    !path.match(SCHEME_REGEXP)
  end

  def self.offsite?(path)
    !self.onsite?(path)
  end

  def progress(level, message)
    puts message unless self.progress_level < level
  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ paths, times, options ],
    }.to_json(*args)
  end

  def self.json_create(object)
    new(*object['a'])
  end

  VERBOSITY_LEVELS = {
    'quiet' => 'Print no progress messages.',
    'minimal' => 'Print only large-scale progress messages',
    'moderate' => '(default) Print more progress messages',
    'debug' => 'Print all progress messages.'
  }

  def self.validate_verbosity(level)
    unless VERBOSITY_LEVELS.keys.include?(level)
      message = "  Error: --verbosity LEVEL must be one of: #{VERBOSITY_LEVELS.keys.join(', ')}; not #{level}."
      raise ArgumentError.new(message)
    end
  end


  def check_options(options)
    extra_options = options.keys - DEFAULT_OPTIONS.keys
    unless extra_options.empty?
      message = <<EOT
Unknown options: #{extra_options.join(', ')};
must be one of: #{DEFAULT_OPTIONS.keys.join(', ')}.
EOT
      raise ArgumentError.new(message)
    end
    %i[open_report report_only github_lines legal news no_op].each do |option|
      check_boolean_option(option)
    end
    check_option(:verbosity, %w[quiet minimal moderate debug])
    check_source_option
  end

  def check_boolean_option(option)
    check_option(option, [true, false])
  end

  def check_option(option, valid_values)
    value = self.options[option]
    unless valid_values.include?(value)
      message = "  Error: --#{option} must be one of: #{valid_values.join(', ')}; not #{value}"
      raise ArgumentError.new(message)
    end
  end

  def check_source_option
    value = self.options[:source]
    return if value.nil?
    return if File.file?(value)
    if value.match(SCHEME_REGEXP)
      url = value
    else
      url = File.join(RubyLinkChecker::BASE_URL, value, '')
    end
    begin
      uri = URI.parse(url)
    rescue => x
      description = "URI(url) failed."
      raise URIParseException.new(description, 'url', url, x.class.name, x.message)
    end
    code = nil
    begin
      response = Net::HTTP.get_response(uri)
      code = response.code.to_i
    rescue => x
      description = "Net::HTTP.get_response(uri) failed."
      raise HTTPResponseException.new(description, 'uri', uri, x.class.name, x.message)
    end
    unless code == 200
      description = "Response code (#{response.code}) for URI #{uri}"
      raise HTTPResponseException.new(description, 'uri', uri, x.class.name, "Bad code: #{response.code}.")
    end
  end

end
