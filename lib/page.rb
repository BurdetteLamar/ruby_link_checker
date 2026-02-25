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
    when path.match(RubyLinkChecker::SchemeRegexp)
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
      :page
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
            File.join(RubyLinkChecker::BASE_URL, path)
          else
            path
          end
    # Parse the url.
    begin
      uri = URI.parse(url)
    rescue => x
      description = "URI(url) failed."
      exception = URIParseException.new(description, 'url', url, x.class.name, x.message)
      exceptions << exception
    end
    # Get the response.
    begin
      response =  Net::HTTP.get_response(uri)
      self.found = true
    rescue => x
      description = "Net::HTTP.get_response(uri) failed."
      exception = HTTPResponseException.new(description, 'uri', uri, x.class.name, x.message)
      exceptions << exception
    end
    # Don't gather links if bad code, or not html, or offsite.
    return if code_bad?(response)
    return unless content_type_html?(response)
    # Get the HTML body.
    body = response.body
    gather_ids(body)
    return unless RubyLinkChecker.onsite?(path)
    gather_links(path, body)
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
        begin
          doc = REXML::Document.new(anchor)
          root = doc.root
          href = root.attributes['href']
          text = root.text
          if text.nil? && root.children.size > 0
            text = root.children[0].text
          end
          if text
            link = Link.new(page_path, lineno, href, text)
            links.push(link)
          end
        rescue REXML::ParseException => x
          description = "REXML::Document.new(anchor) failed."
          exception = AnchorParseException.new(description, 'anchor', anchor, x.class.name, x.message)
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
      values = get_attribute_values(line, %w[ id name ])
      values.each do |value|
        ids.push(value)
      end
    end
  end

  def get_attribute_values(s, attribute_names)
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
      'a'             => [ path, links, ids, exceptions, found, type]
    }.to_json(*args)
  end

  def self.json_create(object)
    # p object
    new(*object['a'])
  end

end
