require 'rexml'

class Report

  include REXML

  TIME_FORMAT = '%Y-%m-%d-%a-%H.%M.%S%z'

  CSS_STYLES = <<EOT
*        { font-family: sans-serif }
.data    { font-family: courier }

.text    { text-align: left }
.number  { text-align: right }
.header  { text-align: center }

.good    { color: rgb(  0,  97,   0); background-color: rgb(198, 239, 206) } /* Green */
.iffy    { color: rgb(156, 101,   0); background-color: rgb(255, 235, 156) } /* Yellow */
.bad     { color: rgb(156,   0,   6); background-color: rgb(255, 199, 206) } /* Redd */
.info    { color: rgb(  0,   0,   0); background-color: rgb(217, 217, 214) } /* Gray */
.header  { color: rgb(255, 255, 255); background-color: rgb(  0,   0,   0) } /* White on black */
EOT

  CSS_CLASSES = {
    label:        'text info',
    table_header: 'header',

    good_text:  'data text good',
    iffy_text:  'data text iffy',
    bad_text:   'data text bad',
    info_text:  'data text info',

    good_count: 'data number good',
    iffy_count: 'data number iffy',
    bad_count:  'data number bad',
    info_count: 'data number info',
  }

  attr_accessor :onsite_paths, :offsite_paths, :paths

  # Create the report for info gathered by the checker.
  def create_report(report_options)
    start_time = Time.now
    dirpath = './ruby_link_checker'
    recent_dirname = Dir.new(dirpath).entries.last
    stash_filename = 'stash.json'
    stash_filepath = File.join(dirpath, recent_dirname, stash_filename)
    json = File.read(stash_filepath)
    checker = JSON.parse(json, create_additions: true)
    checker.options.merge!(report_options)
    self.paths = checker.paths
    verify_links
    report_filename = 'report.html'
    report_filepath = File.join(dirpath, recent_dirname, report_filename)
    self.onsite_paths = {}
    self.offsite_paths = {}
    checker.paths.each_pair do |path, page|
      if RubyLinkChecker.onsite?(path)
        self.onsite_paths[path] = page
      else
        self.offsite_paths[path] = page
      end
    end
    doc = REXML::Document.new('')
    html = doc.add_element(Element.new('html'))

    head = html.add_element(Element.new('head'))
    title = head.add_element(Element.new('title'))
    title.text = 'RubyLinkChecker Report'
    style = head.add_element(Element.new('style'))
    style.text = CSS_STYLES

    body = html.add_element(Element.new('body'))
    add_title(body)
    add_summary(body, checker)
    add_onsite_paths(body, checker)
    add_offsite_paths(body, checker)

    f = File.open(report_filepath, 'w')
    doc.write(f, 2)
    f.close
    puts "Report file: #{report_filepath}"
    report_filepath
  end

  def add_title(body)
    h1 = body.add_element(Element.new('h1'))
    h1.text = "Ruby Link Checker Report"
    h2 = body.add_element('h2')
    h2.text = 'Generated: ' + Time.now.strftime(TIME_FORMAT)
  end

  def add_summary(body, checker)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Summary'
    start_time, end_time, duration =
      formatted_times(checker.times)
    data = [
      {'Start Time' => :label, start_time => :info_text},
      {'End Time' => :label, end_time => :info_text},
      {'Duration' => :label, duration => :info_text},
    ]
    table2(body, data, 'gathering', 'Gathering')

    onsite_link_count = 0
    offsite_link_count = 0
    broken_path_count = 0
    broken_fragment_count = 0
    onsite_paths.each_pair do |path, page|
      page.links.each do |link|
        if RubyLinkChecker.onsite?(link.href)
          onsite_link_count += 1
        else
          offsite_link_count += 1
        end
        case link.status
        when :path_not_found
          broken_path_count += 1
        when :fragment_not_found
          broken_fragment_count += 1
        else
          # Okay.
        end
      end
    end
    data = [
      {'Onsite Pages' => :label, onsite_paths.size => :info_count},
      {'Offsite Pages' => :label, offsite_paths.size => :info_count},
      {'Onsite Links' => :label, onsite_link_count => :info_count},
      {'Offsite Links' => :label, offsite_link_count => :info_count},
      {'Pages Not Found' => :label, broken_path_count => :bad_count},
      {'Fragments Not Found' => :label, broken_fragment_count => :iffy_count},
    ]
    table2(body, data, 'summary', 'Pages and Links')
  end

  def add_onsite_paths(body, checker)
    h2 = body.add_element(Element.new('h2'))
    h2.text = "Onsite Pages (#{onsite_paths.size})"
    p = body.add_element('p')
    p.text = 'The large table below lists the pages found in the Ruby documentation.'

    p = body.add_element('p')
    details = body.add_element('details')
    summary = details.add_element('summary')
    summary.text = 'Colors in the table:'
    p = details.add_element('p')
    p.text = 'The counts of pages and fragments that were not found are color-coded:'
    table = details.add_element('table')
    tr = table.add_element('tr')
    th = tr.add_element('th')
    th.text = 'Color'
    th.add_attribute('class', CSS_CLASSES[:table_header])
    th = tr.add_element('th')
    th.text = 'Status'
    th.add_attribute('class', CSS_CLASSES[:table_header])
    tr = table.add_element('tr')
    td = tr.add_element('td')
    td.text = 'Green'
    td.add_attribute('class', CSS_CLASSES[:good_text])
    td = tr.add_element('td')
    td.text = 'All linked pages or fragments were found.'
    td.add_attribute('class', CSS_CLASSES[:info_text])
    tr = table.add_element('tr')
    td = tr.add_element('td')
    td.text = 'Red'
    td.add_attribute('class', CSS_CLASSES[:bad_text])
    td = tr.add_element('td')
    td.text = 'Some linked pages or onsite fragments were not found.'
    td.add_attribute('class', CSS_CLASSES[:info_text])
    tr = table.add_element('tr')
    td = tr.add_element('td')
    td.text = 'Yellow'
    td.add_attribute('class', CSS_CLASSES[:iffy_text])
    td = tr.add_element('td')
    td.text = 'Some offsite fragments were not found.'
    td.add_attribute('class', CSS_CLASSES[:info_text])
    tr = table.add_element('tr')
    td = tr.add_element('td')
    td.text = 'Gray'
    td.add_attribute('class', CSS_CLASSES[:info_text])
    td = tr.add_element('td')
    td.text = 'The linked pages and fragments were not checked.'
    td.add_attribute('class', CSS_CLASSES[:info_text])

    p = details.add_element('p')
    p.text = 'About fragments that were not found:'
    ul = details.add_element('ul')
    li = ul.add_element('li')
    li.text = <<EOT
An onsite fragment that was not found is shown as red (a definite error)
because every onsite fragment should be found.
(After all, we at Ruby own both the linking page and the linked page.)
EOT
    li = ul.add_element('li')
    li.text = <<EOT
An offsite fragment that was not found is shown as yellow (a possible error)
because some fragment targets on offsite pages may not be found by the link checker.
(It can be complicated.)
EOT

    p = details.add_element('p')
    p.text = 'About pages and fragments that were not checked:'
    ul = details.add_element('ul')
    li = ul.add_element('li')
    li.text = <<EOT
By default, a link is not checked if it is on a historical NEWS page.
This is because the Ruby team has determined that such a page should not be modified.
EOT
    li = ul.add_element('li')
    li.text = <<EOT
By default, a link fragment is not checked if it is on a GitHub page,
and is a line-number fragment (such as 'L12-L41').
This is because there is no such identifier on the GitHub page.
EOT

    p = body.add_element('p')
    p.text = 'The table columns:'
    ul0 = body.add_element('ul')
    li = ul0.add_element('li')
    b = li.add_element('b')
    b.text = 'Path:'
    li.text = <<EOT
The path to the page (on the Ruby documentation site).
If the page has unverified links, the path is linked to details
farther down in this report.
EOT
    ul1 = ul0.add_element('ul')
    li = ul1.add_element('li')
    b = li.add_element('b')
    b.text = 'Onsite:'
    li.text = 'Information about onsite links on the page.'
    ul2 = ul1.add_element('ul')
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Links:'
    li.text = 'Count of onsite links on the page.'
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Not Found:'
    li.text = 'Information about onsite links whose pages or fragments are unverified.'
    ul3 = ul2.add_element('ul')
    li = ul3.add_element('li')
    b = li.add_element('b')
    b.text = 'Pages'
    li.text = 'Count of onsite links whose pages are unverified.'
    li = ul3.add_element('li')
    b = li.add_element('b')
    b.text = 'Fragments:'
    li.text = 'Count of onsite links whose fragments are unverified.'
    ul1 = ul0.add_element('ul')
    li = ul1.add_element('li')
    b = li.add_element('b')
    b.text = 'Offsite:'
    li.text = 'Information about offsite links on the page.'
    ul2 = ul1.add_element('ul')
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Links:'
    li.text = 'Count of offsite links on the page.'
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Not Found:'
    li.text = 'Information about offsite links whose pages or fragments are unverified.'
    ul3 = ul2.add_element('ul')
    li = ul3.add_element('li')
    b = li.add_element('b')
    b.text = 'Pages'
    li.text = 'Count of offsite links whose pages are unverified.'
    li = ul3.add_element('li')
    b = li.add_element('b')
    b.text = 'Fragments:'
    li.text = 'Count of offsite links whose fragments are unverified.'

    p = body.add_element('p')
    p.text = 'The Ruby documentation pages:'

    table = body.add_element('table')


    onsite_paths.keys.sort.each_with_index do |path, page_id|
      if (page_id % 20) == 0
        insert_main_headers(table)
      end
      page = onsite_paths[path]
      if path.empty?
        path = RubyLinkChecker::BASE_URL
      end
      onsite_links = page.links.select {|link| RubyLinkChecker.onsite?(link.href) }
      onsite_page_not_found_links = onsite_links.select {|link| link.status == :path_not_found}
      onsite_fragment_not_found_links = onsite_links.select {|link| link.status == :fragment_not_found}
      offsite_links = page.links - onsite_links
      offsite_page_not_found_links = offsite_links.select {|link| link.status == :path_not_found}
      offsite_fragment_not_found_links = offsite_links.select {|link| link.status == :fragment_not_found}
      tr = table.add_element('tr')
      row_class = :info_text
      tr.add_attribute('class', CSS_CLASSES[row_class])
      values =  [
        path,
        onsite_links.size, onsite_page_not_found_links.size, onsite_fragment_not_found_links.size,
        offsite_links.size, offsite_page_not_found_links.size, offsite_fragment_not_found_links.size,
      ]
      break_count =
        onsite_page_not_found_links.size + onsite_fragment_not_found_links.size +
        offsite_page_not_found_links.size + offsite_fragment_not_found_links.size
      values.each_with_index do |value, i|
        td = tr.add_element('td')
        case i
        when 0 # Page column.
          if (break_count == 0) || suppressible_news?(path, checker)
            td.text = value
          else
            a = td.add_element('a')
            a.add_attribute('href', "##{page_id}")
            a.text = value
          end
        when 1 # Onsite Links column.
          td.text = value
          td.add_attribute('align', 'right')
        when 2 # Onsite Not Found/Pages column.
          td.text = value
          td.add_attribute('align', 'right')
          if suppressible_news?(path, checker)
            cell_class = :info_count
          else
            cell_class = onsite_page_not_found_links.empty? ? :good_count : :bad_count
          end
          td.add_attribute('class', CSS_CLASSES[cell_class])
        when 3 # Onsite Not Found/Fragments column.
          td.text = value
          td.add_attribute('align', 'right')
          if suppressible_news?(path, checker)
            cell_class = :info_count
          else
            cell_class = onsite_fragment_not_found_links.empty? ? :good_count : :bad_count
          end
          td.add_attribute('class', CSS_CLASSES[cell_class])
        when 4 # Offsite Links column.
          td.text = value
          td.add_attribute('align', 'right')
        when 5 # Offsite Not Found/Pages column.
          td.text = value
          td.add_attribute('align', 'right')
          if suppressible_news?(path, checker)
            cell_class = :info_count
          else
            cell_class = offsite_page_not_found_links.empty? ? :good_count : :bad_count
          end
          td.add_attribute('class', CSS_CLASSES[cell_class])
        when 6 # Offsite Not Found/Fragments column.
          td.text = value
          td.add_attribute('align', 'right')
          if suppressible_news?(path, checker)
            cell_class = :info_count
          else
            cell_class = offsite_fragment_not_found_links.empty? ? :good_count : :iffy_count
          end
          td.add_attribute('class', CSS_CLASSES[cell_class])

        end
      end
      next if (break_count == 0) && page.exceptions.empty?
      next if suppressible_news?(path, checker)
      h3 = body.add_element('h3')
      h3.add_attribute('id', page_id)
      a = Element.new('a')
      a.text = path
      a.add_attribute('href', File.join(RubyLinkChecker::BASE_URL, path))
      h3.add_element(a)
      unless break_count == 0
        page.links.each do |link|
          next if link.status == :valid
          path, fragment = link.href.split('#')
          if path && path.match('/github.com/') && path.match('/blob/')
            next if fragment&.match(/^L\d+/) &&
                    !checker.options[:github_lines]
          end
          if checker.paths[path]
            error = 'Fragment not found'
            path_status = :good_text
            fragment_status =  offsite_paths[path] ? :iffy_text : :bad_text
          else
            error = 'Path Not Found'
            path_status = :bad_text
            fragment_status = :info_text
          end
          body.add_element('h4')
          data = [
            {'Path' => :label, path => path_status},
            {'Fragment' => :label, fragment => fragment_status},
            {'Text' => :label, link.text => :info_text},
            {'Line Number' => :label, link.lineno => :info_text},
          ]
          table2(body, data, "#{path}-summary", error)
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

  def insert_main_headers(table)
    tr = table.add_element('tr')
    tr.add_attribute('class', CSS_CLASSES[:table_header])
    th = tr.add_element('th')
    th.text = 'Page'
    th.add_attribute('rowspan', '3')
    th = tr.add_element('th')
    th.text = 'Onsite'
    th.add_attribute('colspan', '3')
    th = tr.add_element('th')
    th.text = 'Offsite'
    th.add_attribute('colspan', '3')
    tr = table.add_element('tr')
    tr.add_attribute('class', CSS_CLASSES[:table_header])
    th = tr.add_element('th')
    th.add_attribute('rowspan', '2')
    th.text = 'Links'
    th = tr.add_element('th')
    th.add_attribute('colspan', '2')
    th.text = 'Not Found'
    th = tr.add_element('th')
    th.add_attribute('rowspan', '2')
    th.text = 'Links'
    th = tr.add_element('th')
    th.add_attribute('colspan', '2')
    th.text = 'Not Found'
    tr = table.add_element('tr')
    tr.add_attribute('class', CSS_CLASSES[:table_header])
    th = tr.add_element('th')
    th.text = 'Pages'
    th = tr.add_element('th')
    th.text = 'Fragments'
    th = tr.add_element('th')
    th.text = 'Pages'
    th = tr.add_element('th')
    th.text = 'Fragments'
  end
  def add_offsite_paths(body, checker)
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

  def table2(parent, data, id = nil, title = nil)
    data = data.dup
    table = parent.add_element(Element.new('table'))
    table.add_attribute('id', id) if id
    if title
      tr = table.add_element(Element.new('tr)'))
      th = tr.add_element(Element.new('th'))
      th.add_attribute('colspan', 2)
      th.add_attribute('class', CSS_CLASSES[:table_header])
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
    parent.add_element('p')
  end

  def suppressible_news?(path, checker)
    path.match(/^NEWS/) && !checker.options[:news]
  end

  def formatted_times(times)
    start_time = times['start']
    end_time = times['end']
    minutes, seconds = (end_time - start_time).divmod(60)
    elapsed = "%d:%02d" % [minutes, seconds]
    [start_time.strftime(TIME_FORMAT), end_time.strftime(TIME_FORMAT),  elapsed]
  end

  def verify_links
    paths.each_pair do |path, page|
      next if page.offsite?
      page.links.each do |link|
        path, fragment = link.href.split('#')
        if path.nil? || path.empty?
          # Fragment only.
          if page.ids.include?(fragment)
            link.status = :valid
          else
            link.status = :fragment_not_found
          end
        elsif fragment.nil?
          # Path only.
          href = link.href.sub(%r[^\./], '').sub(%r[/$], '')
          if paths.keys.include?(href)
            link.status = :valid
          else
            link.status = :path_not_found
          end
        else
          # Both path and fragment.
          target_page = paths[path]
          if target_page.nil?
            link.status = :path_not_found
          elsif target_page.ids.include?(fragment)
            link.status = :valid
          else
            link.status = :fragment_not_found
          end
        end
      end
    end
  end

end
