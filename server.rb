# https://gist.github.com/marcosccm/6245538

require 'webrick'
require 'net/http'
require 'pp'
require 'rexml/document'
require 'pry-byebug'
require 'stringio'
require 'zlib'

class BypassServer < WEBrick::HTTPServlet::AbstractServlet
  MSG_SERVER = '202.248.110.173'.freeze

  def initialize(server, ng_words)
    super(server)
    @ng_words = ng_words
  end

  def do_get(request, response)
    res = Net::HTTP.start(MSG_SERVER, 80) do |http|
      header = request.header.map{|k,v| [k, v.first]}.to_h
      req = Net::HTTP::Get.new(request.path, header)
      http.request( req )
    end
    response.body = res.body
    res.header.each { |k, v| response[k] = v }
  end

  def do_post(request, response)
    res = Net::HTTP.start(MSG_SERVER, 80) do |http|
      header = request.header.map { |k, v| [k, v.first] }.to_h
      req = Net::HTTP::Post.new(request.path, header)
      req.body = request.body
      http.request(req)
    end

    body = res.body
    res.header.each { |k, v| response[k] = v }

    if res.header['Content-Encoding'] == 'gzip'
      Zlib::GzipReader.wrap(StringIO.new(res.body, 'rb')) do |gz|
        body = gz.read
      end
    end

    doc = REXML::Document.new(body)
    doc.root.elements.each('chat') do |element|
      doc.root.elements.delete(element) if @ng_words.any? do |w|
        element.text =~ Regexp.new(w)
      end
    end

    if res.header['Content-Encoding'] == 'gzip'
      sio = StringIO.new('wb')
      gz = Zlib::GzipWriter.new(sio)
      gz.write doc.to_s
      gz.close
      response.body = sio.string.force_encoding('ascii-8bit')
      response['content-encoding'] = 'gzip'
      response['content-length'] = response.body.length
    else
      response.body = doc.to_s
    end
  end
end

ng_words = open('ngwords.flood').read.split(/\r?\n/).reject { |s| s =~ /^#|^$/ }

server = WEBrick::HTTPServer.new Port: 80
server.mount '/', BypathServer, ng_words
server.mount '/*/api', BypathServer, ng_words

server.start
