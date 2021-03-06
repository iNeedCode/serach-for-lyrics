require 'support/text_helper'
require 'open-uri'
require 'nokogiri'
require 'text'

class LyricResource
  include TextHelper
  
  @@filepath = File.join(APP_ROOT, "searched_itunes_titles.txt")

  def self.create_file
    return true if file_usable?
    File.open(@@filepath, 'w') unless File.exists?(@@filepath)
    return file_usable?
  end
  
  def self.file_usable?
    return false unless @@filepath
    return false unless File.exists?(@@filepath)
    return false unless File.readable?(@@filepath)
    return false unless File.writable?(@@filepath)
    return true
  end

  def self.saved_titles
    titles = []
    title = ""
    if file_usable?
      file = File.new(@@filepath, 'r')
      file.each_line do |line|
        title = line.chomp!.split("\t")
        titles << title
      end
    end
    titles
  end
  
  def initialize(track)
    @track = track
    @notification={ :found=>false ,:subtitle => "#{@track[:title]} : #{@track[:album]}", :lyric => ""}
    if already_searched?
      @notification[:title] = "Bereits Erfolgreich gefunden!"
      @notification[:message] = "Fuer erneute Suche Datensatz aus Textfile loeschen"
      @notification[:activate] = 'com.apple.iTunes'
    else
      search_for_lyrics
      save_lyric_to_textfile if @notification[:found]
    end
  end
  
  def search_for_lyrics
    # TODO:
    # metrics = {"sitea.com" => 745, "siteb.com" => 9, "sitec.com" => 10 }
    # metrics.sort_by {|_key, value| value}
    # Dynamic Method call: http://paulsturgess.co.uk/articles/52-calling-dynamic-methods-in-ruby-on-rails
    
    return true if search_under_hindigeetmala
    return true if search_under_bollyrics
    return true if search_under_paksmile
    return true if search_under_bollywoodlyrics
    return false
  end
  
  def search_under_bollyrics
    ressource = "http://bollyrics.com"
    lyrics=""

    title = @track[:title]
    album = @track[:album]

    if title.split.size > 1
      title = title.gsub(' ','-').downcase
    end

    if album.split.size > 1
      album = album.gsub(' ','-').downcase
    else
      album.downcase!
    end

    url = "http://bollyrics.com/#{album}/#{title}-lyrics-movie-#{album}/"
    doc = open_link(url)
    return false unless doc

    hop_over_first_p_tag = 0
    doc.xpath("//div/p[not(@class='post-meta' or @class='must-log-in' or @class='post-date')]").each do |ly|
      hop_over_first_p_tag += 1
      next if hop_over_first_p_tag < 2
      lyrics += ly
      lyrics += "\n\n"
    end

    set_notification(lyrics, ressource)
    return @notification[:found]
  end

  def search_under_hindigeetmala
    ressource = "http://hindigeetmala.com"
    lyrics=""
    album=@track[:album].downcase
    album = album.gsub(' ','_') if album.split.size > 1
    
    url = "http://www.hindigeetmala.com/movie/#{album}.htm"
    doc = open_link(url)
    return false unless doc
    
    #save all album_titles[:title]=>:direct_weblink
    album_titles={}
    doc.xpath('//tbody/tr/td[@width="185"]/a').each do |ly|
      album_titles["#{ly.to_s.scan(/>([^"]*)<\/a>/)}"] = "#{ressource}#{ly.to_s.scan(/href="([^"]*)"/)}"
    end
    
    find_title = find_album_title_on_page(album_titles)

    unless find_title==""
      doc = open_link(find_title.to_s)
      doc.xpath('//div[@class="song"]').each do |line|
        lyrics += line
      end
    end
    
    set_notification(lyrics, ressource)
    return @notification[:found]
  end

  def search_under_bollywoodlyrics
    ressource = "http://bollywoodlyrics.com"
    lyrics=""
    album=@track[:album].downcase
    album = album.gsub(' ','-') if album.split.size > 1
    
    url = "http://www.bollywoodlyrics.com/movie_name/#{album}"
    doc = open_link(url)
    return false unless doc
    
    #save all album titles
    album_titles={}
    doc.xpath('//p[@class="entry-title"]/a').each do |ly|
    		album_titles["#{ly.to_s.scan(/>([^"]*)<\/a>/)}"]= ly.to_s.scan(/href="([^"]*)"/)
    end
 
    find_title = find_album_title_on_page(album_titles)
    
    unless find_title==""
      doc = open_link(find_title.to_s)
        doc.xpath('//div[@class="entry-content"]/pre').each do |line|
          lyrics += line
        end

       if lyrics.size < 50 
         doc.xpath('//div[@class="entry-content"]/p').each do |line|
           lyrics += line
           lyrics += "\n"
        end
      end
    end
    
    set_notification(lyrics, ressource)
    return @notification[:found]
  end
  
  def search_under_paksmile
    ressource = "http://paksmile.com"
    lyrics=""
    album=@track[:album].downcase
    album = album.gsub(' ','-') if album.split.size > 1
    title = @track[:title].downcase
    title = title.gsub(' ','-') if title.split.size > 1
    
    url = "http://www.paksmile.com/lyrics/#{album}/#{title}.asp"
    doc = open_link(url)
    return false unless doc
    
    doc.xpath('//td[@bgcolor="F2FCFF"]/p').each do |ly|
      lyrics += ly
      lyrics += "\n\n"
    end
    
    #if the title didnt match the url, search under the album name
    if lyrics.empty?
      url = "http://www.paksmile.com/lyrics/#{album}/"
      doc = open_link(url)
      
    	album_titles={}
    	doc.xpath('//table[@bgcolor="#F2FCFF"]//strong/a').each do |ly|
      		album_titles["#{ly.to_s.scan(/>([^"]*)<\/a>/)}"]= ly.to_s.scan(/href="([^"]*)"/)
    	end
      
      find_title = find_album_title_on_page(album_titles)
      
      unless find_title.empty?
        url = "http://www.paksmile.com/lyrics/#{album}/#{find_title.to_s}"
        doc = open_link(url)
      
        doc.xpath('//td[@bgcolor="F2FCFF"]/p').each do |ly|
          lyrics += ly
          lyrics += "\n\n"
        end 
      end    
    end
    
    set_notification(lyrics, ressource)
    return @notification[:found]
  end
  
  def notification
    return @notification
  end
  
  def already_searched?
    unless LyricResource.file_usable?
      LyricResource.create_file
    end
    find_title_in_file
  end

  def find_title_in_file
    titles = LyricResource.saved_titles
    found = nil
    found = titles.select do |title|
      title[1].to_s == (@track[:title]) &&
      title[0].to_s == (@track[:album])
    end
    return true unless found.empty? 
    return false
  end
  
  def save_lyric_to_textfile
    return false unless LyricResource.file_usable?
    File.open(@@filepath, 'a') do |file|
      file.puts "#{[@track[:album],@track[:title],@notification[:message]].join("\t")}\n"
    end
    return true
  end
  
  def set_notification(lyrics, ressource)
    if lyrics.size > 50
      @notification[:lyric] = lyrics
      @notification[:found] = true
      @notification[:title] = "Erfolgreich"
      @notification[:message] = ressource
      @notification[:activate] = 'com.apple.iTunes'
    end
  end
  
  def open_link(url)
    begin
      doc = Nokogiri::HTML(open(url))
    rescue Exception => ex
      puts "Error: #{ex}"
      @notification[:message] = "Fehler #{ex}"
      @notification[:title] = "Fehler"
      return false
    end
    doc
  end
  
end