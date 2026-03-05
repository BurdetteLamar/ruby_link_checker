require 'pathname'

class Link

  attr_accessor :page_path, :lineno, :href, :text, :dirname, :status, :path, :fragment

  def initialize(page_path, lineno, href, text)
    self.page_path = page_path
    self.lineno = lineno
    self.href = href
    self.text = text.nil? ? '' : text.strip
    self.dirname = File.dirname(page_path)
    self.status = :unknown
    self.path, self.fragment = self.href.split('#')
    self.path ||= ''
    self.fragment ||= ''
  end

  def cleanpath
    _path = path.sub(%r[^\./], '').sub(%r[/$], '')
    return _path if RubyLinkChecker.offsite?(_path)
    return _path if page_path.empty?
    # updir_count = _path.scan('../').size
    # return _path if updir_count.zero?
    dirname = File.dirname(page_path)
    _path = File.join(dirname, _path)
    Pathname.new(_path).cleanpath.to_s
  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ page_path, lineno, href, text ]
    }.to_json(*args)
  end

  def self.json_create(object)
    # p object
    new(*object['a'])
  end
end
