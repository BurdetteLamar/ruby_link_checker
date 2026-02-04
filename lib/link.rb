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
