#!/usr/bin/env ruby
class Toh2xml      
  attr_reader :input_file_name, :lines_in, :output_file_name, :lines_out

  def self.convert(csv_file_name:)
    new.convert(csv_file_name)
  end

  def initialize
    @map = Hash.new
  end  

  def convert(csv_file_name)
    parse_csv_file(csv_file_name)
    @map = @map.sort_by { |key, val| key.to_i }.to_h
    render_xml_file(csv_file_name.sub(/.csv$/, '.xml'))
    self
  end

  private
  
  def parse_csv_file(input_file_name)
    @input_file_name = input_file_name
    @lines_in = 0

    File.open(input_file_name).each_line do |line|
      parse_csv_line(line)
    end
  end

  def parse_csv_line(line)
    @lines_in += 1

    vals = line.strip!.split(',')
    raise ArgumentError, "line #{@lines_in}: unexpected line format: '#{line}'" if vals.size != 2
    
    key, val = vals.map { |val| val.gsub(/^\s*"|"\s*$/, '') }

    raise ArgumentError, "line #{@lines_in}: duplicate key: #{line}" if @map.has_key? key
    raise ArgumentError, "line #{@lines_in}: duplicate value: #{line}" if @map.has_value? val

    @map[key] = val if [key, val] != ['toh', 'id']
  end

  def render_xml_file(output_file_name)
    @output_file_name = output_file_name
    @lines_out = 0
    File.open(output_file_name, 'w') do |out|
      render_xml_header(out)
      @map.each do |key, val|
        render_xml_item(out, key, val)
      end
      render_xml_footer(out)
    end
  end

  def render_xml_header(out)
    out << <<~XML
            <?xml version='1.0' encoding='utf-8'?>
            <lod>
    XML
    @lines_out += 3
  end

  def render_xml_item(out, key, val)
    out << "    <text key='toh#{key}'>\n" \
           "        <idno type='bdrc' uri='#{val}'/>\n" \
           "    </text>\n"
    @lines_out += 3
  end

  def render_xml_footer(out)
    out << "</lod>\n"
    @lines_out += 1
  end
end


class  ForwardThinkingConverter < Toh2xml
  def render_xml_header(out)
    out << <<~XML
            <?xml version='1.0' encoding='utf-8'?>
            <lod>
              <uris xmlns:eft-toh='http://purl.84000.co/toh'>
    XML
    @lines_out += 3
  end

  def render_xml_item(out, key, val)
    out << "    <uri id='eft-toh:toh#{key}'>#{val}</uri>\n"
    @lines_out += 1
  end

  def render_xml_footer(out)
    out << "  </uris>\n" \
           "</lod>\n"
    @lines_out += 1
  end
end


class  HallowmasConverter < Toh2xml
private

  HEADER_LINE = 'idx,rkts,abstractI,abstractT,expr'.freeze
  REF_TYPES = %w[bdrc-idx rkts-work-id bdrc-work-id bdrc-tibetan-id bdrc-derge-id].freeze

  def parse_csv_line(line)
    line = line.chomp
    @lines_in += 1

    if @lines_in == 1
      if line != HEADER_LINE
        raise(ArgumentError, "line 1: Wrong header line: got: '#{line}', expected: '#{HEADER_LINE}'")
      end
    else
      vals = line.split(',').map { |val| val.gsub(/^\s*"|"\s*$/, '') }
      raise ArgumentError, "line #{@lines_in}: Unexpected line format: '#{line}'" if vals.size != REF_TYPES.size
      idx = vals[0]
      raise ArgumentError, "line #{@lines_in}: Duplicate idx: #{line}" if @map.has_key? idx

      @map[idx] = vals if idx != 'idx' # skip the 1st, header line
    end
  end

  def render_xml_header(out)
    out << <<~XML
            <?xml version='1.0' encoding='utf-8'?>
            <text-refs xmlns="http://read.84000.co/ns/1.0">
    XML
    @lines_out += 2
  end

  def render_xml_item(out, idx, vals)
    out << "    <text key='toh#{idx}'>\n"
    REF_TYPES.each_with_index do |ref_type, i|
      out << "        <ref type='#{ref_type}' value='#{vals[i]}'/>\n"
    end
    out << "    </text>\n"
    @lines_out += 2 + REF_TYPES.size
  end

  def render_xml_footer(out)
    out << '</text-refs>\n'
    @lines_out += 1
  end
end


if __FILE__ == $PROGRAM_NAME
  puts "ruby #{RUBY_VERSION}p#{RUBY_PATCHLEVEL} running"
  puts "command line: #{$PROGRAM_NAME} #{ARGV.join}"
  raise ArgumentError, "Too many command line args!" if ARGV.size > 1
  raise ArgumentError, "Missing command line arg for input file name!" if ARGV.size < 1
  raise ArgumentError, "Not a .csv file name specified - '#{ARGV[0]}'" if not ARGV[0].end_with?('.csv')

  conversion = HallowmasConverter.convert(csv_file_name: ARGV[0])
  puts "#{conversion.lines_in} lines read from file #{conversion.input_file_name}"
  puts "#{conversion.lines_out} lines written to file #{conversion.output_file_name}"
end
