require 'rexml'
require 'net/http/status'

class Report

  include REXML

  TIME_FORMAT = '%Y-%m-%d-%a-%H.%M.%S%z'

  CSS_STYLES = <<EOT
*        { font-family: sans-serif }
.data    { font-family: courier }

.text    { text-align: left }
.number  { text-align: right }
.header  { text-align: center }

.good      { color: rgb(  0,  97,   0); background-color: rgb(198, 239, 206) } /* Green */
.iffy      { color: rgb(156, 101,   0); background-color: rgb(255, 235, 156) } /* Yellow */
.bad       { color: rgb(156,   0,   6); background-color: rgb(255, 199, 206) } /* Red */
.unchecked { color: rgb(  0,   0, 255); background-color: rgb(135, 206, 250) } /* Blue */
.info      { color: rgb(  0,   0,   0); background-color: rgb(217, 217, 214) } /* Gray */
.header    { color: rgb(255, 255, 255); background-color: rgb(  0,   0,   0) } /* White on black */
EOT

  CSS_CLASSES = {
    label:        'text info',
    table_header: 'header',

    good_text:      'data text good',
    iffy_text:      'data text iffy',
    bad_text:       'data text bad',
    unchecked_text: 'data text unchecked',
    info_text:      'data text info',

    good_count:      'data number good',
    iffy_count:      'data number iffy',
    bad_count:       'data number bad',
    unchecked_count: 'data number unchecked',
    info_count:      'data number info',
  }

  attr_accessor :checker, :onsite_paths, :offsite_paths, :paths

  # Create the report for info gathered by the checker.
  def create_report(checker, report_options)
    self.checker = checker
    # Default dir for stashes and reports.
    dirpath = './ruby_link_checker'
    # Dirpath to recent stash and report.
    recent_dirname = Dir.new(dirpath).entries.last
    recent_dirpath = File.join(dirpath, recent_dirname)
    # Read and parse the stash into a new RubyLinkChecker object.
    stash_filename = 'stash.json'
    stash_filepath = File.join(recent_dirpath, stash_filename)
    checker.progress(:minimal, "Reading stash file: #{stash_filepath.inspect}")
    json = File.read(stash_filepath)
    checker = JSON.parse(json, create_additions: true)
    # Merge in the options for reporting (from the CLI).
    checker.options.merge!(report_options)
    # Put checker paths onto Report object.
    self.paths = checker.paths
    # Verify links.
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
    # add_offsite_paths(body, checker)

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
    p = body.add_element('p')
    p.text = <<EOT
This document contains an assessment of the links found in HTML pages
at the given source, "#{checker.source}".
EOT
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
    table2(body, data, id: 'gathering', title: 'Gathering', type: 'Gathering')

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
    broken_path_status = broken_path_count > 0 ? :bad_count : :good_count
    broken_fragment_status = broken_fragment_count > 0 ? :bad_count : :good_count
    data = [
      {'Onsite Pages' => :label, onsite_paths.size => :info_count},
      {'Offsite Pages' => :label, offsite_paths.size => :info_count},
      {'Onsite Links' => :label, onsite_link_count => :info_count},
      {'Offsite Links' => :label, offsite_link_count => :info_count},
      {'Pages Not Found' => :label, broken_path_count => broken_path_status},
      {'Fragments Not Found' => :label, broken_fragment_count => broken_fragment_status},
    ]
    table2(body, data, id: 'summary', title: 'Pages and Links', type: 'Pages and Links')
  end

  def add_onsite_paths(body, checker)
    h2 = body.add_element('h2')
    h2.text = 'Onsite Pages with Unverified Links'

    p = body.add_element('p')
    p.text = 'The large table below lists the pages that have unverified links.'

    p = body.add_element('p')
    p.text = 'Details about the table:'

    details = body.add_element('details')
    summary = details.add_element('summary')
    summary.text = 'Colors in the table:'
    p = details.add_element('p')
    p.text = 'The counts of unverified pages and fragments are color-coded:'
    table = details.add_element('table')
    table.add_attribute('type', 'Colors')
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
    td.text = 'No unverified links; no exceptions.'
    td.add_attribute('class', CSS_CLASSES[:info_text])
    tr = table.add_element('tr')
    td = tr.add_element('td')
    td.text = 'Red'
    td.add_attribute('class', CSS_CLASSES[:bad_text])
    td = tr.add_element('td')
    td.text = 'Some unverified links or exceptions.'
    td.add_attribute('class', CSS_CLASSES[:info_text])
    tr = table.add_element('tr')
    td = tr.add_element('td')
    td.text = 'Yellow'
    td.add_attribute('class', CSS_CLASSES[:iffy_text])
    td = tr.add_element('td')
    td.text = 'Some unverified fragments.'
    td.add_attribute('class', CSS_CLASSES[:info_text])
    tr = table.add_element('tr')
    td = tr.add_element('td')
    td.text = 'Blue'
    td.add_attribute('class', CSS_CLASSES[:unchecked_text])
    td = tr.add_element('td')
    td.text = 'Not checked.'
    td.add_attribute('class', CSS_CLASSES[:info_text])

    p = details.add_element('p')
    p.text = 'About unverified fragments:'
    ul = details.add_element('ul')
    li = ul.add_element('li')
    li.text = <<EOT
An unverified onsite fragment is shown as red (a definite error)
because its identifier should exist.
(After all, we at Ruby own both the linking page and the linked page.)
EOT
    li = ul.add_element('li')
    li.text = <<EOT
An unverified offsite fragment is shown as yellow (a possible error)
because some fragment targets on offsite pages may not be found by the link checker.
(It can be complicated.)
EOT

    p = details.add_element('p')
    p.text = 'About pages and fragments that were not checked:'
    ul = details.add_element('ul')
    li = ul.add_element('li')
    li.text = <<EOT
By default, a link is not checked if it is on a historical LEGAL or NEWS page.
This is because the Ruby team has determined that such a page should not be modified.
EOT
    li = ul.add_element('li')
    li.text = <<EOT
By default, a link fragment is not checked if it is on a GitHub page,
and is a line-number fragment (such as 'L12-L41').
This is because there is no such identifier on the GitHub page.
EOT

    p = body.add_element('p')
    details = body.add_element('details')
    summary = details.add_element('summary')
    summary.text = 'Columns in the table:'
    ul0 = details.add_element('ul')
    li = ul0.add_element('li')
    b = li.add_element('b')
    b.text = 'Path:'
    li.text = <<EOT
The path to the page (on the Ruby documentation site).
If the page has unverified links, the path is linked to details
farther down in this report.
EOT
    li = ul0.add_element('li')
    b = li.add_element('b')
    b.text = 'Onsite:'
    li.text = 'Information about onsite links on the page.'
    ul1 = ul0.add_element('ul')
    li = ul1.add_element('li')
    b = li.add_element('b')
    b.text = 'Links:'
    li.text = 'Count of onsite links on the page.'
    li = ul1.add_element('li')
    b = li.add_element('b')
    b.text = 'Not Found:'
    li.text = 'Information about onsite links whose pages or fragments are unverified.'
    ul2 = ul1.add_element('ul')
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Pages'
    li.text = 'Count of onsite links whose pages are unverified.'
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Fragments:'
    li.text = 'Count of onsite links whose fragments are unverified.'
    li = ul0.add_element('li')
    b = li.add_element('b')
    b.text = 'Offsite:'
    li.text = 'Information about offsite links on the page.'
    ul1 = ul0.add_element('ul')
    li = ul1.add_element('li')
    b = li.add_element('b')
    b.text = 'Links:'
    li.text = 'Count of offsite links on the page.'
    li = ul1.add_element('li')
    b = li.add_element('b')
    b.text = 'Not Found:'
    li.text = 'Information about offsite links whose pages or fragments are unverified.'
    ul2 = ul1.add_element('ul')
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Pages'
    li.text = 'Count of offsite links whose pages are unverified.'
    li = ul2.add_element('li')
    b = li.add_element('b')
    b.text = 'Fragments:'
    li.text = 'Count of offsite links whose fragments are unverified.'
    li = ul0.add_element('li')
    b = li.add_element('b')
    b.text = 'Exceptions:'
    li.text = 'Count of exceptions raised during assessment.'

    body.add_element('p')

    table = body.add_element('table')
    table.add_attribute('type', 'Main')


    page_id = 0
    onsite_paths.keys.sort.each do |path|
      puts "Reporting #{path.inspect}"
      page = onsite_paths[path]
      if path.empty?
        path = checker.options[:source]
      end
      onsite_links = page.links.select {|link| RubyLinkChecker.onsite?(link.href) }
      onsite_page_not_found_links = onsite_links.select {|link| link.status == :path_not_found}
      onsite_fragment_not_found_links = onsite_links.select {|link| link.status == :fragment_not_found}
      offsite_links = page.links - onsite_links
      offsite_page_not_found_links = offsite_links.select {|link| link.status == :path_not_found}
      offsite_fragment_not_found_links = offsite_links.select {|link| link.status == :fragment_not_found}
      break_count =
        onsite_page_not_found_links.size + onsite_fragment_not_found_links.size +
        offsite_page_not_found_links.size + offsite_fragment_not_found_links.size
      next if break_count == 0
      if (page_id % 20) == 0
        insert_main_headers(table)
      end
      page_id += 1
      tr = table.add_element('tr')
      row_class = :info_text
      tr.add_attribute('class', CSS_CLASSES[row_class])
      values =  [
        path,
        onsite_links.size, onsite_page_not_found_links.size, onsite_fragment_not_found_links.size,
        offsite_links.size, offsite_page_not_found_links.size, offsite_fragment_not_found_links.size,
        page.exceptions.size,
      ]
      values.each_with_index do |value, i|
        td = tr.add_element('td')
        case i
        when 0 # Page column.
          if ((break_count == 0) && (page.exceptions.empty?)) || suppressible?(path, checker)
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
          if suppressible?(path, checker)
            cell_class = :unchecked_count
          else
            cell_class = onsite_page_not_found_links.empty? ? :good_count : :bad_count
          end
          td.add_attribute('class', CSS_CLASSES[cell_class])
        when 3 # Onsite Not Found/Fragments column.
          td.text = value
          td.add_attribute('align', 'right')
          if suppressible?(path, checker)
            cell_class = :unchecked_count
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
          if suppressible?(path, checker)
            cell_class = :unchecked_count
          else
            cell_class = offsite_page_not_found_links.empty? ? :good_count : :bad_count
          end
          td.add_attribute('class', CSS_CLASSES[cell_class])
        when 6 # Offsite Not Found/Fragments column.
          td.text = value
          td.add_attribute('align', 'right')
          if suppressible?(path, checker)
            cell_class = :unchecked_count
          else
            cell_class = offsite_fragment_not_found_links.empty? ? :good_count : :iffy_count
          end
          td.add_attribute('class', CSS_CLASSES[cell_class])
          when 7 # Exceptions column.
            td.text = value
            td.add_attribute('align', 'right')
            if suppressible?(path, checker)
              cell_class = :unchecked_count
            else
              cell_class = (value == 0) ? :good_count : :bad_count
            end
            td.add_attribute('class', CSS_CLASSES[cell_class])
        end
      end
      next if (break_count == 0) && page.exceptions.empty?
      next if suppressible?(path, checker)
      h3 = body.add_element('h3')
      h3.add_attribute('id', page_id)
      a = Element.new('a')
      a.text = path
      a.add_attribute('href', File.join(checker.source, path))
      h3.add_element(a)
      unless break_count == 0
        page.links.each do |link|
          next if link.status == :valid
          path, fragment = link.href.split('#')
          target_page = checker.paths[path]
          if target_page&.found
            error = 'Fragment Not Found'
            path_status = :good_text
            if onsite_paths[path]
              fragment_status = :bad_text
            elsif github_lines_fragment?(path, fragment)
              fragment_status = checker.options[:github_lines] ? :bad_text : :unchecked_text
            else
              fragment_status = :bad_text
            end
          else
            error = 'Path Not Found'
            path_status = :bad_text
            fragment_status = :info_text
          end
          if target_page
            code = target_page.code
            code_text = "#{code} #{Net::HTTP::STATUS_CODES[code]}"
            code_status = target_page.found ? :good_text : :bad_text
          else
            code = ''
            code_status = :info_text
          end
          data = [
            {'Path' => :label, path => path_status},
            {'HTTP Status' => :label, code_text => code_status},
            {'Fragment' => :label, fragment => fragment_status},
            {'Text' => :label, link.text => :info_text},
            {'Line Number' => :label, link.lineno => :info_tex},
          ]
          table2(body, data, id: "#{path}-summary", title: error, type: error)
        end
      end
      page.exceptions.each do |exception|
        data = [
          {'Event' => :label, exception.description => :bad_text},
          {'Arg Name' => :label, exception.argname => :info_text},
          {'Arg Value' => :label, exception.argvalue => :info_text},
          {'Class Name' => :label, exception.class_name => :info_text},
          {'Message' => :label, exception.message => :info_text},
        ]
        table2(body, data, id: "#{path}-exception", title: 'Exception', type: 'Exception')
      end

      body.add_element(Element.new('p'))
    end
  end

  def github_lines_fragment?(path, fragment)
    path &&
      path.match('/github.com/') &&
      path.match('/blob/') &&
      fragment&.match(/^L\d+/)
  end

  def insert_main_headers(table)
    tr = table.add_element('tr')
    tr.add_attribute('class', CSS_CLASSES[:table_header])
    th = tr.add_element('th')
    th.text = 'Path'
    th.add_attribute('rowspan', '3')
    th = tr.add_element('th')
    th.text = 'Onsite'
    th.add_attribute('colspan', '3')
    th = tr.add_element('th')
    th.text = 'Offsite'
    th.add_attribute('colspan', '3')
    th = tr.add_element('th')
    th.text = 'Exceptions'
    th.add_attribute('rowspan', '3')
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

  def table2(parent, data, id: nil, title: nil, type: nil)
    data = data.dup
    table = parent.add_element(Element.new('table'))
    table.add_attribute('id', id) if id
    table.add_attribute('type', type) if type
    if title
      tr = table.add_element(Element.new('tr'))
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

  def suppressible?(path, checker)
    (path.match(/^NEWS/) && !checker.options[:news]) ||
      (path.match(/^LEGAL/) && !checker.options[:legal])
  end

  def formatted_times(times)
    start_time = times['start']
    end_time = times['end']
    minutes, seconds = (end_time - start_time).divmod(60)
    elapsed = "%d:%02d" % [minutes, seconds]
    [start_time.strftime(TIME_FORMAT), end_time.strftime(TIME_FORMAT),  elapsed]
  end

  def verify_links
    paths.keys.sort.each do |path|
      page = paths[path]
      next if RubyLinkChecker.offsite?(path)
      checker.progress(:minimal, "Verifying links on #{path.inspect}")
      page.links.each do |link|
        if link.path.empty?
          if link.fragment.empty?
            link.status = :path_not_found
          elsif page.ids.include?(link.fragment)
            link.status = :valid
          else
            link.status = :fragment_not_found
          end
        else # Link path non-empty.
          if RubyLinkChecker.offsite?(link.path)
            next unless link.path.start_with?('http')
            linked_page = paths[link.path]
            if linked_page
              if linked_page.found
                link.status = :valid
              else
                link.status = :path_not_found
              end
            else
              link.status = :path_not_found
            end
          else # Onsite.
            cleaned_path = link.cleanpath
            target_page = paths[cleaned_path]
            if target_page.nil? || !target_page.found
              link.status = :path_not_found
            elsif link.fragment.empty? || target_page.ids.include?(link.fragment)
              link.status = :valid
            else
              link.status = :fragment_not_found
            end
          end
        end
      end
    end
  end

end
