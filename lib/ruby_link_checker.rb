require 'net/http'
require 'rexml'

# A program to check links on pages in the official Ruby documentation
# at https://docs.ruby-lang.org/en/master.
#
class RubyLinkChecker

  include REXML

  # URL for documentation base page.
  BASE_URL = 'https://docs.ruby-lang.org/en/master'

  # Hash of Page objects by path.
  attr_accessor :source_pages, :offsite_pages

  # Array of paths yet to be processed.
  attr_accessor :pending_pages

  attr_accessor :counts

  def initialize
    self.source_pages = {}
    self.pending_pages = []
    self.counts = {
      source_pages: 0,
      offsite_pages: 0,
      onsite_links_found: 0,
      offsite_links_found: 0,
      links_checked: 0,
      links_broken: 0,
    }
  end

  def check_links
    counts[:start_time] = Time.new
    # Seed pending with base url.
    pending_pages << ''
    # Work on the pendings.
    until pending_pages.empty?
      # break if source_pages.size >= 1231
      # Take the next pending page; skip if already done.
      path = pending_pages.shift
      next if source_pages[path]
      # New page.
      page = Page.new(path)
      if RubyLinkChecker.onsite?(path)
        source_pages[path] = page
      else
        counts[:offsite_pages] += 1
      end
      # Pend any new paths.
      page.links.each do |link|
        if RubyLinkChecker.onsite?(link.href)
          counts[:onsite_links_found] += 1
        else
          counts[:offsite_links_found] += 1
        end
        href = link.href
        # Done if we're on https://docs.ruby-lang.org/en/; don't do the other releases.
        break if href == 'master'
        next if href.start_with?('#')
        path = href.sub(%r[^\./], '').sub(%r[/$], '')
        next if path.match(/^(LEGAL|NEWS|mailto)/)
        path, _ = path.split('#')
        stem = link.stem
        if RubyLinkChecker.onsite?(path) && stem != '.'
          path = File.join(stem, path)
        end
        # Skip if done or pending.
        next if source_pages.include?(path)
        next if pending_pages.include?(path)
        # Pend it.
        # $stderr.puts "    #{path}"
        pending_pages.push(path)
      end
    end
    counts[:end_time] = Time.new
    generate_report
    # source_pages.keys.sort.each do |path|
      # page = source_pages[path]
      # page.links.each do |link|
      #   p link
      # end
      # page.exceptions.each do |exception|
      #   p exception.class
      #   p exception.message
      #   p exception.argname
      #   p exception.argvalue
      #   p exception.exception_class
      #   p exception.exception_message
      # end
    # end
  end

  def generate_report
    doc = REXML::Document.new('')
    root = doc.add_element(Element.new('root'))
    head = root.add_element(Element.new('head'))
    title = head.add_element(Element.new('title'))
    title.text = 'RubyLinkChecker Report'
    style = head.add_element(Element.new('style'))
    style.text = <<EOT
*        { font-family: sans-serif }
.data    { font-family: courier }
.center  { text-align: center }
.good    { color: rgb(  0,  97,   0); background-color: rgb(198, 239, 206) } /* Greenish */
.iffy    { color: rgb(156, 101,   0); background-color: rgb(255, 235, 156) } /* Yellowish */
.bad     { color: rgb(156,   0,   6); background-color: rgb(255, 199, 206) } /* Reddish */
.neutral { color: rgb(  0,   0,   0); background-color: rgb(217, 217, 214) } /* Grayish */
EOT
    body = root.add_element(Element.new('body'))
    h1 = body.add_element(Element.new('h1'))
    h1.text = 'RDocLinkChecker Report'
    add_summary(body)
    add_pages(body)
    doc.write($stdout, 2)
  end

  Classes = {
    label: 'label center neutral',
    good: 'data center good',
    iffy: 'data center iffy',
    bad: 'data center bad',
  }

  def table2(parent, data, id = nil, title = nil)
    data = data.dup
    table = parent.add_element(Element.new('table'))
    table.add_attribute('id', id) if id
    if title
      tr = table.add_element(Element.new('tr)'))
      th = tr.add_element(Element.new('th'))
      th.add_attribute('colspan', 2)
      if title.kind_of?(REXML::Element)
        th.add_element(title)
      else
        th.text = title
      end
    end
    data.each do |row_h|
      label, label_class, value, value_class = row_h.flatten
      tr = table.add_element(Element.new('tr'))
      td = tr.add_element(Element.new('td'))
      td.text = label
      td.add_attribute('class', Classes[label_class])
      td = tr.add_element(Element.new('td'))
      if value.kind_of?(REXML::Element)
        td.add_element(value)
      else
        td.text = value
      end
      td.add_attribute('class', Classes[value_class])
    end
  end

  def add_summary(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Summary'

    # Times table.
    elapsed_time = counts[:end_time] - counts[:start_time]
    seconds = elapsed_time % 60
    minutes = (elapsed_time / 60) % 60
    hours = (elapsed_time/3600)
    elapsed_time_s = "%2.2d:%2.2d:%2.2d" % [hours, minutes, seconds]
    format = "%Y-%m-%d-%a-%H:%M:%SZ"
    start_time_s = counts[:start_time].strftime(format)
    end_time_s = counts[:end_time].strftime(format)
    data = [
      {'Start Time' => :label, start_time_s => :good},
      {'End Time' => :label, end_time_s => :good},
      {'Elapsed Time' => :label, elapsed_time_s => :good},
    ]
    table2(body, data, 'times', 'Times')
    body.add_element(Element.new('p'))

    # Counts.
    data = [
      {'Onsite Pages' => :label, source_pages.size => :good},
      {'Offsite Pages' => :label, counts[:offsite_pages] => :good},
      {'Onsite Links Found' => :label, counts[:onsite_links_found] => :good},
      {'Offsite Links Found' => :label, counts[:offsite_links_found] => :good},
      {'Links Checked' => :label, counts[:links_checked] => :good},
      {'Links Broken' => :label, counts[:links_broken] => :bad},
    ]
    table2(body, data, 'counts', 'Counts')
    body.add_element(Element.new('p'))

  end

  def add_pages(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Source Pages'
    source_pages.keys.sort.each do |path|
      page = source_pages[path]
      next unless RubyLinkChecker.onsite?(path)
      next if page.exceptions.empty?
      div = body.add_element(Element.new('div'))
      div.add_attribute('class', 'broken_page')
      div.add_attribute('path', path)
      div.add_attribute('count', page.exceptions.size)
      h3 = div.add_element(Element.new('h3'))
      a = Element.new('a')
      a.text = "#{path} (#{page.exceptions.size})"
      a.add_attribute('href', File.join(BASE_URL, path))
      h3.add_element(a)
      page.exceptions.each do |e|
        p = body.add_element(Element.new('p'))
        p.text = e.inspect
      end
    end
  end

  SchemeList = URI.scheme_list.keys.map {|scheme| scheme.downcase}

  # Returns whether the path is onsite.
  def self.onsite?(path)
    return true if path == ''
    return false unless path.match(/^[a-zA-Z]/)
    potential_scheme = path.match(/^\w*/).to_s
    !SchemeList.include?(potential_scheme)
  end

  class Page

    attr_accessor :path, :links, :ids, :exceptions, :found

    def initialize(path)
      self.path = path
      self.links = []
      self.ids = []
      self.exceptions = []
      self.found = false
      # Form URL.
      url = if RubyLinkChecker.onsite?(path)
              File.join(BASE_URL, path)
            else
              path
            end
      $stderr.puts(url)
      # Parse the url.
      begin
        uri = URI(url)
      rescue => x
        message = "URI(url) failed for #{url}."
        exception = URIParseException.new(message, 'url', url, x)
        exceptions << exception
      end
      # Get the response.
      begin
        response =  Net::HTTP.get_response(uri)
        found = true
      rescue => x
        message = "Net::HTTP.get_response(uri) failed for #{uri}."
        exception = HTTPResponseException.new(message, 'uri', uri, x)
        exceptions << exception
      end
      # Don't gather links if bad code, or not html, or not onsite.
      return if code_bad?(response)
      return unless content_type_html?(response)
      return unless RubyLinkChecker.onsite?(path)
      # Get the HTML body.
      body = response.body
      gather_links(path, body)
      gather_ids(body)
    end

    # Returns whether the code is bad (zero or >= 400).
    def code_bad?(response)
      return false if response.nil?
      code = response.code.to_i
      return false if code.nil?
      (code == 0) || (code >= 400)
    end

    # Returns whether the response body is HTML.
    def content_type_html?(response)
      return false unless response
      return false unless response['Content-Type']
      response['Content-Type'].match('html')
    end

    # Gathers links from the page body.
    def gather_links(path, body)
      lines = body.lines
      # Some links are multi-line; i.e., '<a ... >' and '</a>' are not on the same line.
      # Therefore we capture a possibly multi-line snippet containing both.
      snippet = ''
      i = 0
      while true
        line = lines[i]
        break if line.nil?
        i += 1
        next unless line.match(%r:<a :)
        lineno = i
        snippet << line
        until line.match(%r:</a>:)
          line = lines[i]
          i += 1
          snippet << line
        end
        # Use REXML to parse each anchor.
        get_anchors(snippet).each do |anchor|
          next if anchor.match('<img ')
          begin
            doc = REXML::Document.new(anchor)
            href = doc.root.attributes['href']
            text = doc.root.text
            link = Link.new(path, lineno, href, text)
            links.push(link)
          rescue REXML::ParseException => x
            message = "REXML::Document.new(anchor) failed for #{anchor}."
            exception = AnchorParseException.new(message, 'anchor', anchor, x)
            exceptions << exception
          end
          snippet = ''
        end
      end
    end

    def get_anchors(snippet)
      # A 1-line snippet may contain multiple links,
      # and a 1-link snippet may have multiple lines.
      anchors = []
      snippet.split(%r[<a ]).each do |s|
        anchor, _ = s.split(%r[</a>])
        anchors << "<a #{anchor}</a>"
      end
      anchors.shift # First one is junk (from split).
      anchors
    end

    def gather_ids(body)
      body.lines.each do |line|
        line.chomp!
        next if line.match('footmark')
        next if line.match('foottext')
        next unless line.match(%r:<(\w+) id=":)
        end_tag = "</#{$1}>"
        line += '>' unless line.end_with?('>')
        line += end_tag unless line.end_with?(end_tag)
        line.sub!(' hidden', ' hidden="true"')
        begin
          doc = REXML::Document.new(line)
          id = doc.root.attributes['id']
          ids.push(id)
        rescue REXML::ParseException => x
          message = "REXML::Document.new(line) failed for #{line}."
          exception = IdParseException.new(message, 'line', line, x)
          self.exceptions << exception
        end
      end
    end

  end

  class Link
    attr_accessor :stem, :lineno, :href, :text
    def initialize(linker, lineno, href, text)
      self.lineno = lineno
      self.text = text.nil? ? '' : text.strip
      dirname = File.dirname(linker)
      while href.start_with?('../') do
        href.sub!('../', '')
        dirname = File.dirname(dirname)
      end
      self.href = href
      self.stem = dirname
    end
  end

  class RubyLinkCheckerException < Exception
    attr_accessor :message, :argname, :argvalue, :exception_class, :exception_message
    def initialize(message, argname, argval, exception)
      super(message)
      self.message = message
      self.argname = argname
      self.argvalue = argvalue
      self.exception_class = exception.class.to_s
      self.exception_message = exception.message
    end
  end

  class URIParseException < RubyLinkCheckerException

  end

  class HTTPResponseException < RubyLinkCheckerException

  end

  class AnchorParseException < RubyLinkCheckerException

  end

  class IdParseException < RubyLinkCheckerException

  end

end

if $0 == __FILE__
  RubyLinkChecker.new.check_links
end