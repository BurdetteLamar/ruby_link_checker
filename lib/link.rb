class Link

  attr_accessor :path, :lineno, :href, :text, :dirname, :status

  def initialize(path, lineno, href, text)
    self.path = path
    self.lineno = lineno
    self.href = href
    self.text = text.nil? ? '' : text.strip
    dirname = File.dirname(path)
    while href.start_with?('../') do
      href.sub!('../', '')
      dirname = File.dirname(dirname)
    end
    self.dirname = dirname
    self.status = :unknown
  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ path, lineno, href, text ]
    }.to_json(*args)
  end

  def self.json_create(object)
    # p object
    new(*object['a'])

  end
end
