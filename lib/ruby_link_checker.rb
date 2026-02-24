require 'net/http'
require 'json'
require 'json/add/time'
require 'fileutils'

require_relative 'page'
require_relative 'link'
require_relative 'exception'
require_relative 'report'

# A class to check links on pages in the official Ruby documentation
# at https://docs.ruby-lang.org/en/master.
#
# TODO:
# - Fix verbosity: stdout, levels.
# - Report:
#   - Open report in browser (all platforms).
#   - Report URL parsing exceptions.
#   - Report REXML parsing exceptions.
# - RubyLinkChecker:
#   - Check up on rescued exceptions.
#   - Verify Github lineno fragments.
#   - On-site page: gather ids only if fragments cited.
#   - Off-site page: fetch and gather ids only if fragments cited.
#   - Correctly handle links in subclasses.
#   - Parse images as special cases?

class RubyLinkChecker

  SchemeList = URI.scheme_list.keys.map {|scheme| scheme.downcase}
  SchemeRegexp = Regexp.new('^(' + SchemeList.join('|') + ')')
  DEFAULT_OPTIONS = {
    verbosity: 'minimal',
  }

  # URL for documentation base page.
  BASE_URL = 'https://docs.ruby-lang.org/en/master'

  attr_accessor :paths, :times, :options

  # Return a new RubyLinkChecker object.
  def initialize(paths = {}, times = {}, options: {})
    self.paths = paths
    self.times = times
    self.options = DEFAULT_OPTIONS.merge(options)
  end

  def create_stash
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
      page = Page.new(path)
      progress("%4.4d queued:  Dequeueing %s" % [paths_queue.size, path])
      page.check_page
      paths[path] = page
      # Queue any new paths.
      page.links.each do |link|
        href = link.href
        next if href.start_with?('#')
        _path = href.sub(%r[^\./], '').sub(%r[/$], '')
        _path, _ = _path.split('#')
        dirname = link.dirname
        if RubyLinkChecker.onsite?(_path) && dirname != '.'
          _path = File.join(dirname, _path)
        end
        # Skip if already done or already queued.
        next if paths.include?(_path)
        next if paths_queue.include?(_path)
        # Queue it.
        progress("%4.4d queued:  Queueing %s" % [paths_queue.size, _path])
        paths_queue.push(_path)
      end
    end
    times['end'] = Time.now
    json = JSON.pretty_generate(self)
    dirpath = File.join('./ruby_link_checker', timestamp)
    FileUtils.mkdir_p(dirpath)
    filename = 'stash.json'
    filepath = File.join(dirpath, filename)
    File.write(filepath, json)
  end

  def create_report(report_options)
    Report.new.create_report(report_options)
  end

  # Returns whether the path is onsite.
  def self.onsite?(path)
    return true if path == ''
    return true if path.start_with?('./')
    return true if path.start_with?('#')
    potential_scheme = path.match(/^\w*/).to_s
    return false if SchemeList.include?(potential_scheme)
    path.match(/^[a-zA-Z]/) ? true : false
  end

  def progress(message)
    puts message unless options[:verbosity] == 'quiet'
  end

  def debug(message)
    puts message if options[:verbosity] == 'debug'
  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ paths, times ],
    }.to_json(*args)
  end

  def self.json_create(object)
    new(*object['a'])
  end

end
