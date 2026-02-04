require 'net/http'
require 'rexml'
require 'json'
require 'json/add/time'

require_relative 'page'
require_relative 'link'
require_relative 'exception'
require_relative 'report'

# A class to check links on pages in the official Ruby documentation
# at https://docs.ruby-lang.org/en/master.

class RubyLinkChecker

  include REXML

  SchemeList = URI.scheme_list.keys.map {|scheme| scheme.downcase}
  SchemeRegexp = Regexp.new('^(' + SchemeList.join('|') + ')')

  # URL for documentation base page.
  BASE_URL = 'https://docs.ruby-lang.org/en/master'

  attr_accessor :onsite_paths, :offsite_paths, :counts

  # Return a new RubyLinkChecker object.
  def initialize(onsite_paths = {}, offsite_paths = {}, counts = {})
    self.onsite_paths = onsite_paths
    self.offsite_paths = offsite_paths
    if counts.empty?
      counts = {
        'onsite_links_found' => 0,
        'offsite_links_found' => 0,
      }
    end
    self.counts = counts
    @pending_paths = []
  end

  def create_stash
    counts['gather_start_time'] = Time.new
    # Seed pending with base url.
    @pending_paths << ''
    # Work on the pending pages.
    until @pending_paths.empty?
      # Take the next pending page; skip if already done.
      path = @pending_paths.shift
      next if onsite_paths[path]
      # New page.
      page = Page.new(path)
      $stderr.puts "#{page.type} #{path}"
      page.check_page
      if page.onsite?
        next unless page.found
        onsite_paths[path] = page
      else
        offsite_paths[path] = page
      end
      # Pend any new paths.
      page.links.each do |link|
        if RubyLinkChecker.onsite?(link.href)
          counts['onsite_links_found'] += 1
        else
          counts['offsite_links_found'] += 1
        end
        href = link.href
        next if href.start_with?('#')
        _path = href.sub(%r[^\./], '').sub(%r[/$], '')
        _path, _ = _path.split('#')
        dirname = link.dirname
        if RubyLinkChecker.onsite?(_path) && dirname != '.'
          _path = File.join(dirname, _path)
        end
        # Skip if done or pending.
        next if onsite_paths.include?(_path)
        next if offsite_paths.include?(_path)
        next if @pending_paths.include?(_path)
        # Pend it.
        @pending_paths.push(_path)
      end
    end
    counts['gather_end_time'] = Time.new
    json = JSON.pretty_generate(self)
    File.write('t.json', json)
  end

  def create_report
    json = File.read('t.json')
    checker = JSON.parse(json, create_additions: true)
    checker.verify_links
    Report.new(checker)
  end

  def verify_links
    onsite_paths.each_pair do |path, page|
      page.links.each do |link|
        path, fragment = link.href.split('#')
        if path.nil? || path.empty?
          # Fragment only.
          if page.ids.include?(fragment)
            link.status = :valid
          else
            link.status = :broken
          end
        elsif fragment.nil?
          # Path only.
          href = link.href.sub(%r[^\./], '').sub(%r[/$], '')
          if onsite_paths.keys.include?(href) ||
             offsite_paths.keys.include?(href)
            link.status = :valid
          else
            link.status = :broken
          end
        else
          # Both path and fragment.
          target_page = target_page(path)
          if target_page.nil?
            link.status = :broken
          elsif target_page.ids.include?(fragment)
            link.status = :valid
          else
            link.status = :broken
          end
        end
      end
    end
  end

  def target_page(path)
    onsite_paths[path] || offsite_paths[path]
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

  def self.get_attribute_values(s, attribute_names)
    re = Regexp.new('(' + attribute_names.join('|') + ')="')
    values = []
    scanner = StringScanner.new(s)
    while (s0 = scanner.check_until(re))
      scanner.pos += s0.length
      if (s1 = scanner.check_until(/"/))
        value = s1[0..-2]
        values.push(value)
      end
    end
    values
  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ onsite_paths, offsite_paths, counts ],
    }.to_json(*args)
  end

  def self.json_create(object)
    new(*object['a'])
  end

end

if $0 == __FILE__
  checker = RubyLinkChecker.new
  # checker.create_stash
  checker.create_report
end