require File.expand_path(File.join(File.dirname(__FILE__), "helper"))

class TestNokogiri < Nokogiri::TestCase
  def test_versions
    version_match = /\d+\.\d+\.\d+/
    assert_match version_match, Nokogiri::VERSION
    assert_match version_match, Nokogiri::LIBXML_VERSION

    if defined?(FFI)
      assert_equal 'ffi', Nokogiri::VERSION_INFO['libxml']['binding']
      if RUBY_PLATFORM =~ /java/
        assert_equal 'jruby', Nokogiri::VERSION_INFO['libxml']['platform']
      else
        assert_equal 'ruby', Nokogiri::VERSION_INFO['libxml']['platform']
      end
      assert Nokogiri.ffi?
    else
      assert_equal 'extension', Nokogiri::VERSION_INFO['libxml']['binding']

      assert_match version_match, Nokogiri::VERSION_INFO['libxml']['compiled']
      assert_equal Nokogiri::LIBXML_VERSION, Nokogiri::VERSION_INFO['libxml']['compiled']
      assert ! Nokogiri.ffi?
    end

    assert_match version_match, Nokogiri::VERSION_INFO['libxml']['loaded']
    Nokogiri::LIBXML_PARSER_VERSION =~ /(\d)(\d{2})(\d{2})/
    major = $1.to_i
    minor = $2.to_i
    bug   = $3.to_i
    assert_equal "#{major}.#{minor}.#{bug}", Nokogiri::VERSION_INFO['libxml']['loaded']
  end

  def test_xml?
    doc = Nokogiri.parse(File.read(XML_FILE))
    assert doc.xml?
    assert !doc.html?
  end

  def test_html?
    doc = Nokogiri.parse(File.read(HTML_FILE))
    assert !doc.xml?
    assert doc.html?
  end

  def test_nokogiri_method_with_html
    doc1 = Nokogiri(File.read(HTML_FILE))
    doc2 = Nokogiri.parse(File.read(HTML_FILE))
    assert_equal doc1.serialize, doc2.serialize
  end

  def test_nokogiri_method_with_block
    doc = Nokogiri { b "bold tag" }
    assert_equal('<b>bold tag</b>', doc.to_html.chomp)
  end

  def test_make_with_html
    doc = Nokogiri.make("<b>bold tag</b>")
    assert_equal('<b>bold tag</b>', doc.to_html.chomp)
  end

  def test_make_with_block
    doc = Nokogiri.make { b "bold tag" }
    assert_equal('<b>bold tag</b>', doc.to_html.chomp)
  end
  
  SLOP_HTML = <<-END
  <html>
    <body>
      <ul>
        <li class='red'>one</li>
        <li class='blue'>two</li>
      </ul>
      <div>
        one
        <div>div two</div>
      </div>
    </body>
  </html>
  END

  def test_slop_css
    doc = Nokogiri::Slop(<<-eohtml)
    <html>
      <body>
        <div>
          one
          <div class='foo'>
            div two
            <div class='foo'>
              div three
            </div>
          </div>
        </div>
      </body>
    </html>
    eohtml
    assert_equal "div", doc.html.body.div.div('.foo').name
  end

  def test_slop
    doc = Nokogiri::Slop(SLOP_HTML)

    assert_equal "one", doc.html.body.ul.li.first.text
    assert_equal "two", doc.html.body.ul.li(".blue").text
    assert_equal "div two", doc.html.body.div.div.text

    assert_equal "two", doc.html.body.ul.li(:css => ".blue").text

    assert_equal "two", doc.html.body.ul.li(:xpath => "position()=2").text
    assert_equal "one", doc.html.body.ul.li(:xpath => ["contains(text(),'o')"]).first.text
    assert_equal "two", doc.html.body.ul.li(:xpath => ["contains(text(),'o')","contains(text(),'t')"]).text

    assert_raise(NoMethodError) { doc.nonexistent }
  end
  
  def test_slop_decorator
    doc = Nokogiri(SLOP_HTML)
    assert !doc.decorators(Nokogiri::XML::Node).include?(Nokogiri::Decorators::Slop)

    doc.slop!
    assert doc.decorators(Nokogiri::XML::Node).include?(Nokogiri::Decorators::Slop)

    doc.slop!
    assert_equal 1, doc.decorators(Nokogiri::XML::Node).select { |d| d == Nokogiri::Decorators::Slop }.size
  end

  def test_substitute_entities
    #
    #  this example taken from http://xmlsoft.org/entities.html
    #
    xml = <<EOXML
<?xml version="1.0"?>
<!DOCTYPE EXAMPLE SYSTEM "example.dtd" [
<!ENTITY xml "Extensible Markup Language">
]>
<EXAMPLE>
   &xml;
</EXAMPLE>
EOXML

    Nokogiri::XML.substitute_entities = 0
    doc = Nokogiri::XML.parse(xml)
    assert_match %r(&xml;), doc.xpath("/EXAMPLE").to_xml
    assert_no_match %r(Extensible Markup Language), doc.xpath("/EXAMPLE").to_xml

# TODO: libxml appears to be totally borked with regards to substituting entities.
#     Nokogiri::XML.substitute_entities = 1
#     doc = Nokogiri::XML.parse(xml)
#     assert_no_match %r(&xml;), doc.xpath("/EXAMPLE").to_xml
#     assert_match %r(Extensible Markup Language), doc.xpath("/EXAMPLE").to_xml
  end

end
