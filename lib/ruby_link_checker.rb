require 'net/http'
require 'rexml'

# A program to check links on pages in the official Ruby documentation
# at https://docs.ruby-lang.org/en/master.
#
class RubyLinkChecker

  # URL for documentation base page.
  BASE_URL = 'https://docs.ruby-lang.org/en/master'

  # Not allowed to fix links on these, so exclude.
  EXCLUDE_PATTERN = %r[master/(NEWS|LEGAL)]

  # Hash of Page objects, by URI.
  attr_accessor :pages

  # Array of URIs yet to be processed.
  attr_accessor :pending

  def initialize
    self.pages = {}
    self.pending = []
  end
  
  def check_links
    # Seed pending with base URI.
    base_uri = URI.parse(BASE_URL)
    pending << base_uri
    # Work on the pendings.
    until pending.empty?
      uri = pending.shift
      # New Page.
      page = Page.new(uri)
      pages[uri] = page
      # Pend any new URIs.
      page.uris.each do |uri|
        path = uri.host.nil? ? uri.path : File.join(uri.host, uri.path)
        unless uri.scheme.nil?
          path = uri.scheme + '://' + path
        end
        next if uri.to_s.match(EXCLUDE_PATTERN)
        unless pending.include?(uri)
          p uri.to_s
          pending.push(uri)
        end
      end
    end
  end

  class Page

    attr_accessor :uri, :uris, :exceptions

    def initialize(uri)
      self.uri = uri
      self.uris = []
      self.exceptions = []
      begin
        p uri
        response =  Net::HTTP.get_response(uri)
        if response.code == '301'
          response = Net::HTTP.get_response(URI(response['Location']))
        end
      rescue => x
        raise unless x.class.name.match(/^(Net|Socket|IO::TimeoutError|Errno::)/)
      end
      # Don't load if bad code, or no response, or if not html.
      return if code_bad?(response)
      return unless content_type_html?(response)
      gather_links(response.body)
    end

    # Returns whether the code is bad (zero or >= 400).
    def code_bad?(response)
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
            href.sub!(%r:^[\./]*:, '')
            begin
              uri = URI(href)
              if uri.scheme.nil?
                uri = URI(File.join(BASE_URL, href))
              end
              next unless ['http', 'https', nil].include? uri.scheme
              uris.push(uri)
            rescue URI::InvalidURIError => x
              self.exceptions << x
            end
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

  end

end

if $0 == __FILE__
  RubyLinkChecker.new.check_links
end