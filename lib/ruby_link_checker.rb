require 'net/http'
require 'rexml'

# A program to check links on pages in the official Ruby documentation
# at https://docs.ruby-lang.org/en/master.
#
class RubyLinkChecker

  # URL for documentation base page.
  BASE_URL = 'https://docs.ruby-lang.org/en/master'

  # Ruby core team does not allow fixing broken links on these, so exclude.
  EXCLUDE_PATTERN = /^(NEWS|LEGAL)/

  # Hash of Page objects by path.
  attr_accessor :pages

  # Array of paths yet to be processed.
  attr_accessor :pages_pending

  def initialize
    self.pages = {}
    self.pages_pending = []
  end
  
  def check_links
    # Seed pending with base url.
    pages_pending << ''
    # Work on the pendings.
    until pages_pending.empty?
      path = pages_pending.shift
      next if pages[path]
      page = Page.new(path)
      pages[path] = page
      # Pend any new paths.
      page.links.each do |link|
        path = link.href
        next if path.start_with?('http')
        path = link.href.sub(%r:^[\./]*:, '')
        break if path == 'master/'
        next if path.match(EXCLUDE_PATTERN)
        path, _ = path.split('#', 2)
        next if pages_pending.include?(path)
        next if pages.include?(path)
        pages_pending.push(path)
      end
    end
    pages.keys.sort.each do |path|
      puts path
      page = pages[path]
      page.exceptions.each do |exception|
        p exception.class
        p exception.message
      end
    end
  end

  class Page

    attr_accessor :path, :links, :exceptions

    def initialize(path)
      self.path = path
      self.links = []
      self.exceptions = []
      begin
        full_path = path.start_with?('http') ? path : File.join(BASE_URL, path)
        uri = URI.parse(full_path)
        response =  Net::HTTP.get_response(uri)
        if response.code == '301'
          response = Net::HTTP.get_response(URI(response['Location']))
        end
      rescue => x
        exceptions << x
      end
      # Don't gather links if bad code, or not html, or off-site.
      return if code_bad?(response)
      return unless content_type_html?(response)
      return if off_site?(path)
      body = response.body
      gather_links(body)
      # gather_ids(body)
    end

    def off_site?(path)
      path.start_with?('http')
    end

    # Returns whether the code is bad (zero or >= 400).
    def code_bad?(response)
      return false if response.nil?
      code = response.code.to_i
      return false if code.nil?
      (code == 0) || (code >= 400)
    end

    # Returns whether the response body should be HTML.
    def content_type_html?(response)
      return false unless response
      return false unless response['Content-Type']
      response['Content-Type'].match('html')
    end

    def gather_links(body)
      snippet = ''
      lines = body.lines
      i = 0
      while true
        line = lines[i]
        break if line.nil?
        i += 1
        next unless line.match(%r:<a :)
        snippet << line
        until line.match(%r:</a>:)
          line = lines[i]
          i += 1
          snippet << line
        end
        get_anchors(snippet).each do |anchor|
          begin
            doc = REXML::Document.new(anchor)
            href = doc.root.attributes['href']
            text = doc.root.text
            link = Link.new(path, href, text)
            links.push(link)
          rescue REXML::ParseException => x
            self.exceptions << x
          end
            snippet = ''
        end
      end
    end

    def get_anchors(snippet)
      anchors = []
      snippet.split(%r[<a ]).each do |s|
        anchor, _ = s.split(%r[</a>])
        anchors << "<a #{anchor}</a>"
      end
      anchors.shift
      anchors
    end

    # Returns whether the page is offsite.
    def offsite?
      self.path.start_with?('http')
    end

    def gather_ids(body)
      body.lines.each do |line|
        line.chomp!
        next unless line.match(%r:<(\w+) id=":)
        p [$1, line.end_with?("<#{$1}>", line)]
      end
      # # Some ids are in the as (anchors).
      # body.search('a').each do |a|
      #   id = a.attr(id)
      #   ids.push(id) if id
      # end
      #
      # # Method ids are in divs, but gather only method-detail divs.
      # body.search('div').each do |div|
      #   class_ = div.attr('class')
      #   next if class_.nil?
      #   next unless class_.match('method-')
      #   id = div.attr('id')
      #   ids.push(id) if id
      # end
      #
      # # Constant ids are in dts.
      # body.search('dt').each do |dt|
      #   id = dt.attr('id')
      #   ids.push(id) if id
      # end
      #
      # # Label ids are in headings.
      # %w[h1 h2 h3 h4 h5 h6].each do |tag|
      #   body.search(tag).each do |h|
      #     id = h.attr('id')
      #     ids.push(id) if id
      #   end
      # end

    end

  end

  class Link
    attr_accessor :path, :href, :text
    def initialize(path, href, text)
      self.path = path
      self.href = href
      self.text = text.nil? ? '' : text.strip
    end
  end
end

if $0 == __FILE__
  RubyLinkChecker.new.check_links
end