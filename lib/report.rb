require 'rexml'

class Report

  include REXML

  TIME_FORMAT = '%Y-%m-%d-%a-%k:%M:%SZ'

  CSS_STYLES = <<EOT
*        { font-family: sans-serif }
.data    { font-family: courier }
.text    { text-align: left }
.count   { text-align: right }
.good    { color: rgb(  0,  97,   0); background-color: rgb(198, 239, 206) } /* Greenish */
.iffy    { color: rgb(156, 101,   0); background-color: rgb(255, 235, 156) } /* Yellowish */
.bad     { color: rgb(156,   0,   6); background-color: rgb(255, 199, 206) } /* Reddish */
.info    { color: rgb(  0,   0,   0); background-color: rgb(217, 217, 214) } /* Grayish */
EOT

  CSS_CLASSES = {
    label: 'text info',
    good_text: 'data text good',
    iffy_text: 'data text iffy',
    bad_text: 'data text bad',
    info_text: 'data text info',
    good_count: 'data count good',
    iffy_count: 'data count iffy',
    bad_count: 'data count bad',
    info_count: 'data count info',
  }

  # Create the report for info gathered by the checker.
  def initialize(checker)

    @checker = checker

    doc = REXML::Document.new('')
    html = doc.add_element(Element.new('html'))

    head = html.add_element(Element.new('head'))
    title = head.add_element(Element.new('title'))
    title.text = 'RubyLinkChecker Report'
    style = head.add_element(Element.new('style'))
    style.text = CSS_STYLES

    body = html.add_element(Element.new('body'))
    add_title(body)
    add_summary(body)
    add_onsite_paths(body)
    add_offsite_paths(body)

    doc.write($stdout, 2)

  end

  def add_title(body)
    h1 = body.add_element(Element.new('h1'))
    h1.text = "RDocLinkChecker Report"
    h2 = body.add_element('h2')
    h2.text = 'Generated: ' + Time.now.strftime(TIME_FORMAT)
  end

  def add_summary(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Summary'

    start_time, end_time, duration =
      formatted_times(@checker.counts['gather_start_time'], @checker.counts['gather_end_time'])
    data = [
      {'Start Time' => :label, start_time => :info_text},
      {'End Time' => :label, end_time => :info_text},
      {'Duration' => :label, duration => :info_text},
    ]
    table2(body, data, 'gathering', 'Gathered Time')

    onsite_links = 0
    offsite_links = 0
    broken_links = 0
    @checker.onsite_paths.each_pair do |path, page|
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
      {'Onsite Pages' => :label, @checker.onsite_paths.size => :info_count},
      {'Offsite Pages' => :label, @checker.offsite_paths.size => :info_count},
      {'Onsite Links' => :label, onsite_links => :info_count},
      {'Offsite Links' => :label, offsite_links => :info_count},
      {'Broken Links' => :label, broken_links => :bad_count},
    ]
    table2(body, data, 'summary', 'Pages and Links')
  end

  def add_onsite_paths(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = "Onsite Pages (#{@checker.onsite_paths.size})"

    table = body.add_element('table')
    headers = ['Path', 'Ids', 'Onsite Links', 'Offsite Links', 'Broken Links']
    tr = table.add_element('tr')
    headers.each do |header|
      th = tr.add_element('th')
      th.text = header
      th.add_attribute('class', CSS_CLASSES[:info_text])
    end
    @checker.onsite_paths.keys.sort.each_with_index do |path, page_id|
      page = @checker.onsite_paths[path]
      if path.empty?
        path = RubyLinkChecker::BASE_URL
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
      next if broken_links.empty? && page.exceptions.empty?
      h3 = body.add_element('h3')
      h3.add_attribute('id', page_id)
      a = Element.new('a')
      a.text = path
      a.add_attribute('href', File.join(RubyLinkChecker::BASE_URL, path))
      h3.add_element(a)
      unless broken_links.empty?
        page.links.each do |link|
          next unless link.status == :broken
          path, fragment = link.href.split('#')
          if @checker.onsite_paths[path] || @checker.offsite_paths[path]
            error = 'Fragment not found'
            path_status = :good_text
            fragment_status =  @checker.offsite_paths[path] ? :iffy_text : :bad_text
          else
            error = 'Page Not Found'
            path_status = :bad_text
            fragment_status = :info_text
          end
          h4 = body.add_element('h4')
          h4.text = error
          data = [
            {'Path' => :label, path => path_status},
            {'Fragment' => :label, fragment => fragment_status},
            {'Text' => :label, link.text => :info_text},
            {'Line Number' => :label, link.lineno => :info_text},
          ]
          table2(body, data, "#{path}-summary")
        end
      end
      page.exceptions.each do |exception|
        ul = body.add_element('ul')
        %i[message argname argvalue exception].each do |method|
          value = exception.send(method)
          li = ul.add_element('li')
          li.text = "#{method}: #{value}"
        end
      end

      body.add_element(Element.new('p'))
    end
  end

  def add_offsite_paths(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = "Offsite Pages (#{@checker.offsite_paths.size})"

    paths_by_url = {}
    @checker.offsite_paths.each_pair do |path, page|
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
      td.add_attribute('class', CSS_CLASSES[label_class])
      td = tr.add_element(Element.new('td'))
      if value.kind_of?(REXML::Element)
        td.add_element(value)
      else
        td.text = value
      end
      td.add_attribute('class', CSS_CLASSES[value_class])
    end
  end

  def formatted_times(start_time, end_time)
    minutes, seconds = (end_time - start_time).divmod(60)
    elapsed = "%d:%02d" % [minutes, seconds]
    [start_time.strftime(TIME_FORMAT), end_time.strftime(TIME_FORMAT),  elapsed]
  end

end
