require 'net/http'
require 'rexml'
require 'json'
require 'json/add/time'

# A class to check links on pages in the official Ruby documentation
# at https://docs.ruby-lang.org/en/master.
#
class RubyLinkChecker

  include REXML

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

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ onsite_paths, offsite_paths, counts ],
    }.to_json(*args)
  end

  def self.json_create(object)
    new(*object['a'])
  end

  def gather_pages
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
        path = href.sub(%r[^\./], '').sub(%r[/$], '')
        path, _ = path.split('#')
        dirname = link.dirname
        if RubyLinkChecker.onsite?(path) && dirname != '.'
          path = File.join(dirname, path)
        end
        # Skip if done or pending.
        next if onsite_paths.include?(path)
        next if offsite_paths.include?(path)
        next if @pending_paths.include?(path)
        # Pend it.
        # $stderr.puts path
        @pending_paths.push(path)
      end
    end
    counts['gather_end_time'] = Time.new
  end

  def evaluate_links
    counts['evaluate_start_time'] = Time.new
    verify_links
    generate_report
    counts['evaluate_end_time'] = Time.new
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

  def generate_report
    doc = REXML::Document.new('')
    html = doc.add_element(Element.new('html'))
    head = html.add_element(Element.new('head'))
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
    body = html.add_element(Element.new('body'))
    h1 = body.add_element(Element.new('h1'))
    h1.text = "RDocLinkChecker Report"
    h2 = body.add_element('h2')
    h2.text = 'Generated: ' + Time.now.strftime(TIME_FORMAT)
    add_summary(body)
    add_onsite_paths(body)
    add_offsite_paths(body)
    doc.write($stdout, 2)
  end

  Classes = {
    label: 'label center neutral',
    good: 'data center good',
    iffy: 'data center iffy',
    bad: 'data center bad',
    info: 'data center neutral',
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

  TIME_FORMAT = '%Y-%m-%e-%a-%k:%M:%SZ'

  def formatted_times(start_time, end_time)
    minutes, seconds = (end_time - start_time).divmod(60)
    elapsed = "%d:%02d" % [minutes, seconds]
    [start_time.strftime(TIME_FORMAT), end_time.strftime(TIME_FORMAT),  elapsed]
  end

  def add_summary(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Summary'

    start_time, end_time, duration =
      formatted_times(counts['gather_start_time'], counts['gather_end_time'])
    data = [
      {'Start Time' => :label, start_time => :info},
      {'End Time' => :label, end_time => :info},
      {'Duration' => :label, duration => :info},
    ]
    table2(body, data, 'gathering', 'Gathered Time')

    onsite_links = 0
    offsite_links = 0
    broken_links = 0
    onsite_paths.each_pair do |path, page|
      page.links.each do |link|
        if RubyLinkChecker.onsite?(link.href)
          onsite_links += 1
        else
          offsite_links += 1
        end
        broken_links += 1 if link.status == :broken
      end
    end
    data = [
      {'Onsite Pages' => :label, onsite_paths.size => :info},
      {'Offsite Pages' => :label, offsite_paths.size => :info},
      {'Onsite Links' => :label, onsite_links => :info},
      {'Offsite Links' => :label, offsite_links => :info},
      {'Broken Links' => :label, broken_links => :bad},
    ]
    table2(body, data, 'summary', 'Pages and Links')
  end

  def add_onsite_paths(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = "Onsite Pages (#{onsite_paths.size})"

    table = body.add_element('table')
    headers = ['Path', 'Ids', 'Onsite Links', 'Offsite Links', 'Broken Links']
    tr = table.add_element('tr')
    headers.each do |header|
      th = tr.add_element('th')
      th.text = header
      th.add_attribute('class', Classes[:info])
    end
    onsite_paths.keys.sort.each_with_index do |path, page_id|
      page = onsite_paths[path]
      if path.empty?
        path = BASE_URL
      end
      onsite_links = page.links.select {|link| RubyLinkChecker.onsite?(link.href) }
      offsite_links = page.links - onsite_links
      broken_links = onsite_links.select {|link| link.status == :broken }
      broken_links += offsite_links.select {|link| link.status == :broken }
      tr = table.add_element('tr')
      status = broken_links.empty? ? 'good' : 'bad'
      tr.add_attribute('class', status)
      [path, page.ids.size, onsite_links.size, offsite_links.size, broken_links.size].each_with_index do |value, i|
        td = tr.add_element('td')
        if i == 0
          if broken_links.empty?
            td.text = value
          else
            a = td.add_element('a')
            a.add_attribute('href', "##{page_id}")
            a.text = value
          end
        else
          td.text = value
          td.add_attribute('align', 'right')
        end
      end
      next if broken_links.empty?
      h3 = body.add_element('h3')
      h3.add_attribute('id', page_id)
      a = Element.new('a')
      a.text = path
      a.add_attribute('href', File.join(BASE_URL, path))
      h3.add_element(a)
      unless broken_links.empty?
        page.links.each do |link|
          next unless link.status == :broken
          path, fragment = link.href.split('#')
          if onsite_paths[path] || offsite_paths[path]
            error = 'Fragment not found'
            path_status = :good
            fragment_status = :bad
          else
            error = 'Page Not Found'
            path_status = :bad
            fragment_status = :info
          end
          h4 = body.add_element('h4')
          h4.text = error
          data = [
            {'Path' => :label, path => path_status},
            {'Fragment' => :label, fragment => fragment_status},
            {'Text' => :label, link.text => :info},
            {'Line Number' => :label, link.lineno => :info},
          ]
          table2(body, data, "#{path}-summary")
        end
      end
      # unless page.exceptions.empty?
      #   page.exceptions.each do |exception|
      #     ul = body.add_element('ul')
      #     %i[message argname argvalue exception_class exception_message].each do |method|
      #       value = exception.send(method)
      #       li = ul.add_element('li')
      #       li.text = "#{method}: #{value}"
      #     end
      #   end
      # end

      body.add_element(Element.new('p'))
    end
  end


  def add_offsite_paths(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = "Offsite Pages (#{offsite_paths.size})"

    paths_by_url = {}
    offsite_paths.each_pair do |path, page|
      next unless page.found
      uri = URI(path)
      if uri.scheme.nil?
        url = uri.hostname
      else
        url = File.join(uri.scheme + '://', uri.hostname)
      end
      next if url.nil?
      paths_by_url[url] = [] unless paths_by_url[url]
      _path = uri.path
      _path = "#{_path}?#{uri.query}" unless uri.query.nil?
      paths_by_url[url].push([_path, page.ids.size])
    end
    paths_by_url.keys.sort.each do |url|
      h3 = body.add_element(Element.new('h3'))
      a = h3.add_element(Element.new('a'))
      a.text = url
      a.add_attribute('href', url)
      paths = paths_by_url[url]
      next if paths.empty?
      ul = body.add_element(Element.new('ul'))
      paths.sort.each do |pair|
        path, id_count = *pair
        li = ul.add_element(Element.new('li'))
        a = li.add_element(Element.new('a'))
        a.text = path.empty? ? url : path
        a.text += " (#{id_count} ids)"
        a.add_attribute('href', File.join(url, path))
      end
    end
  end

  SchemeList = URI.scheme_list.keys.map {|scheme| scheme.downcase}
  SchemeRegexp = Regexp.new('^(' + SchemeList.join('|') + ')')

  # Returns whether the path is onsite.
  def self.onsite?(path)
    return true if path == ''
    return true if path.start_with?('./')
    return true if path.start_with?('#')
    potential_scheme = path.match(/^\w*/).to_s
    return false if SchemeList.include?(potential_scheme)
    path.match(/^[a-zA-Z]/) ? true : false
  end

  class Page

    attr_accessor :path, :links, :ids, :exceptions, :found, :type

    def initialize(path, links = [], ids = [], exceptions = [], found = false, type = :unknown)
      self.path = path
      self.links = links
      self.ids = ids
      self.exceptions = exceptions
      self.found = found
      self.type = type == :unknown ? Page.get_type(path) : type
    end

    def self.get_type(path)
      case
      when path.match(SchemeRegexp)
        :url
      when path.start_with?('./')
        :class
      when path.start_with?('#')
        :class
      when path == ''
        :page
      when path.match(/^fatal/)
        :class
      when path.match(/^([a-z]|NEWS|README|COPYING|LEGAL)/)
        :page
      when path.match(/^[A-Z]/)
        :class
      else
        :unknown
      end
    end

    def onsite?
      [:class, :page].include?(type)
    end

    def offsite?
      [:url, :unknown].include?(type)
    end

    def check_page
      # Form URL.
      url = if RubyLinkChecker.onsite?(path)
              File.join(BASE_URL, path)
            else
              path
            end
      # $stderr.puts(url)
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
        self.found = true
      rescue => x
        message = "Net::HTTP.get_response(uri) failed for #{uri}."
        exception = HTTPResponseException.new(message, 'uri', uri, x)
        exceptions << exception
      end
      # Don't gather links if bad code, or not html, or not onsite.
      return if code_bad?(response)
      return unless content_type_html?(response)
      # Get the HTML body.
      body = response.body
      gather_ids(body)
      # $stderr.puts "    Ids: #{ids.size} #{path}"
      return unless RubyLinkChecker.onsite?(path)
      gather_links(path, body)
      # $stderr.puts "    Links: #{links.size} #{path}"
    end

    def to_json(*args)
      {
        JSON.create_id  => self.class.name,
        'a'             => [ path, links, ids, exceptions, found, type]
      }.to_json(*args)
    end

    def self.json_create(object)
      # p object
      new(*object['a'])
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
    def gather_links(page_path, body)
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
            link = Link.new(page_path, lineno, href, text)
            links.push(link)
            # $stderr.puts "    Href: #{RubyLinkChecker.onsite?(href)} #{href}"
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
        # $stderr.puts line if line.match('anchor')
        next if line.match('footmark')
        next if line.match('foottext')
        next unless line.match(%r[id=])
        next unless line.match(%r[<(\w+)])
        end_tag = "</#{$1}>"
        line += '>' unless line.end_with?('>')
        line += end_tag unless line.end_with?(end_tag)
        line.sub!(' hidden', ' hidden="true"')
        begin
          doc = REXML::Document.new(line)
          eles = REXML::XPath.match(doc, '//*')
          names = eles.map{|element| element.name }
          # $stderr.puts names.to_s if names.include?('dt')
          eles.each do |element|
            id = element.attributes['id']
            ids.push(id) if id
          end
        rescue REXML::ParseException => x
          message = "REXML::Document.new(line) failed for #{line}."
          exception = IdParseException.new(message, 'line', line, x)
          self.exceptions << exception
        end
      end
    end

  end

  class Link

    attr_accessor :dirname, :lineno, :href, :text, :status

    def initialize(page_path, lineno, href, text)
      self.lineno = lineno
      self.text = text.nil? ? '' : text.strip
      dirname = File.dirname(page_path)
      while href.start_with?('../') do
        href.sub!('../', '')
        dirname = File.dirname(dirname)
      end
      self.href = href
      self.dirname = dirname
      self.status = :unknown
    end

    def to_json(*args)
      {
        JSON.create_id  => self.class.name,
        'a'             => [ dirname, lineno, href, text ]
      }.to_json(*args)
    end

    def self.json_create(object)
      # p object
      new(*object['a'])
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
  checker = RubyLinkChecker.new
  checker.gather_pages
  json = JSON.pretty_generate(checker)
  File.write('t.json', json)
  json = File.read('t.json')
  checker = JSON.parse(json, create_additions: true)
  checker.evaluate_links
end