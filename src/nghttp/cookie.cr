# yanked from http/cookie with additions to format of expires option
# need to insure this is kept in sync if cookie is updated

module NGHTTP
  # Represents a cookie with all its attributes. Provides convenient
  # access and modification of them.
  class Cookie
    @from_host : String? = nil
    property :from_host
    property name : String
    property value : String
    property path : String
    property expires : Time?
    property max_age : Time::Span?
    property domain : String?
    property secure : Bool
    property http_only : Bool
    property extension : String?
    @creation_time : Time

    def_equals_and_hash name, value, path, expires, domain, secure, http_only

    def initialize(@name : String, value : String, @path : String = "/",
                   @expires : Time? = nil, @max_age : Time::Span? = nil, @domain : String? = nil,
                   @secure : Bool = false, @http_only : Bool = false,
                   @extension : String? = nil)
      @creation_time = Time.now
      @name = URI.unescape name
      @value = URI.unescape value
    end

    def to_set_cookie_header
      path = @path
      expires = @expires
      max_age = @max_age
      domain = @domain
      String.build do |header|
        header << "#{URI.escape @name}=#{URI.escape value}"
        header << "; domain=#{domain}" if domain
        header << "; path=#{path}" if path
        header << "; expires=#{HTTP.rfc1123_date(expires)}" if expires
        header << "; max-age=#{max_age.total_seconds}" if max_age
        header << "; Secure" if @secure
        header << "; HttpOnly" if @http_only
        header << "; #{@extension}" if @extension
      end
    end

    def to_cookie_header
      "#{@name}=#{URI.escape value}"
    end

    # Returns the `Time` at which this cookie will expire, or `nil` if it will not expire.
    # Uses *max-age* and *expires* values to calculate the time.
    # By default, this function uses the creation time of this cookie as the offset for max-age, if max-age is set.
    # To use a different offset, provide a `Time` object to *time_reference*.
    def expiration_time(time_reference = @creation_time)
      if max_age = @max_age
        time_reference + max_age
      else
        @expires
      end
    end

    def expired?(time_reference = @creation_time)
      @max_age == 0.seconds || expiration_time(time_reference).try &.<(Time.now) || false
    end

    # :nodoc:
    module Parser
      module Regex
        CookieName     = /[^()<>@,;:\\"\[\]?={} \t\x00-\x1f\x7f]+/
        CookieOctet    = /[!#-+\--:<-\[\]-~]/
        CookieValue    = /(?:"#{CookieOctet}*"|#{CookieOctet}*)/
        CookiePair     = /(?<name>#{CookieName})=(?<value>#{CookieValue})/
        DomainLabel    = /[A-Za-z0-9\-]+/
        DomainIp       = /(?:\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
        Time           = /(?:\d{2}:\d{2}:\d{2})/
        Month          = /(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/
        Weekday        = /(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/
        Wkday          = /(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)/
        PathValue      = /[^\x00-\x1f\x7f;]+/
        DomainValue    = /(?:#{DomainLabel}(?:\.#{DomainLabel})?|#{DomainIp})+/
        Zone           = /(?:UT|GMT|EST|EDT|CST|CDT|MST|MDT|PST|PDT|[+-]?\d{4})/
        RFC1036Date    = /#{Weekday}, \d{2}-#{Month}-\d{2} #{Time} GMT/
        RFC1036ModDate = /#{Wkday}, \d{2}-#{Month}-\d{4} #{Time} GMT/
        RFC1123Date    = /#{Wkday}, \d{1,2} #{Month} \d{2,4} #{Time} #{Zone}/
        ANSICDate      = /#{Wkday} #{Month} (?:\d{2}| \d) #{Time} \d{4}/
        SaneCookieDate = /(?:#{RFC1123Date}|#{RFC1036Date}|#{RFC1036ModDate}|#{ANSICDate})/
        ExtensionAV    = /(?<extension>[^\x00-\x1f\x7f]+)/
        HttpOnlyAV     = /(?<http_only>HttpOnly)/i
        SecureAV       = /(?<secure>Secure)/i
        PathAV         = /Path=(?<path>#{PathValue})/i
        DomainAV       = /Domain=(?<domain>#{DomainValue})/i
        MaxAgeAV       = /Max-Age=(?<max_age>[0-9]+)/i
        ExpiresAV      = /Expires=(?<expires>#{SaneCookieDate})/i
        CookieAV       = /(?:#{ExpiresAV}|#{MaxAgeAV}|#{DomainAV}|#{PathAV}|#{SecureAV}|#{HttpOnlyAV}|#{ExtensionAV})/
      end

      CookieString    = /(?:^|; )#{Regex::CookiePair}/
      SetCookieString = /^#{Regex::CookiePair}(?:; #{Regex::CookieAV})*$/

      def parse_cookies(header)
        header.scan(CookieString).each do |pair|
          yield Cookie.new(pair["name"], pair["value"])
        end
      end

      def parse_cookies(header)
        cookies = [] of Cookie
        parse_cookies(header) { |cookie| cookies << cookie }
        cookies
      end

      def parse_set_cookie(header)
        match = header.match(SetCookieString)
        return unless match

        expires = parse_time(match["expires"]?)
        max_age = match["max_age"]? ? match["max_age"].to_i64.seconds : nil

        Cookie.new(
          match["name"], match["value"],
          path: match["path"]? || "/",
          expires: expires,
          max_age: max_age,
          domain: match["domain"]?,
          secure: match["secure"]? != nil,
          http_only: match["http_only"]? != nil,
          extension: match["extension"]?
        )
      end

      private def parse_time(string)
        return unless string
string=string.gsub(/[^-]-[^-]/) {|i| "#{i[0]} #{i[2]}" }
        HTTP.parse_time(string)
      end

      extend self
    end
  end

  # Represents a collection of cookies as it can be present inside
  # a HTTP request or response.
  class Cookies
    include Enumerable(Cookie)

    # Create a new instance by parsing the `Cookie` and `Set-Cookie`
    # headers in the given `HTTP::Headers`.
    #
    # See `HTTP::Request#cookies` and `HTTP::Client::Response#cookies`.
    def self.from_headers(headers) : self
      new.tap { |cookies| cookies.fill_from_headers(headers) }
    end

    # Filling cookies by parsing the `Cookie` and `Set-Cookie`
    # headers in the given `HTTP::Headers`.
    def fill_from_headers(headers)
      if values = headers.get?("Cookie")
        values.each do |header|
          Cookie::Parser.parse_cookies(header) { |cookie| self << cookie }
        end
      end

      if values = headers.get?("Set-Cookie")
        values.each do |header|
          Cookie::Parser.parse_set_cookie(header).try { |cookie| self << cookie }
        end
      end
      self
    end

    # Create a new empty instance.
    def initialize
      @cookies = {} of String => Cookie
    end

    # Set a new cookie in the collection with a string value.
    # This creates a never expiring, insecure, not HTTP only cookie with
    # no explicit domain restriction and the path `/`.
    #
    # ```
    # request = HTTP::Request.new "GET", "/"
    # request.cookies["foo"] = "bar"
    # ```
    def []=(key, value : String)
      self[key] = Cookie.new(key, value)
    end

    # Set a new cookie in the collection to the given `HTTP::Cookie`
    # instance. The name attribute must match the given *key*, else
    # `ArgumentError` is raised.
    #
    # ```
    # response = HTTP::Client::Response.new(200)
    # response.cookies["foo"] = HTTP::Cookie.new("foo", "bar", "/admin", Time.now + 12.hours, secure: true)
    # ```
    def []=(key, value : Cookie)
      unless key == value.name
        raise ArgumentError.new("Cookie name must match the given key")
      end

      @cookies[key] = value
    end

    # Get the current `HTTP::Cookie` for the given *key*.
    #
    # ```
    # request.cookies["foo"].value # => "bar"
    # ```
    def [](key)
      @cookies[key]
    end

    # Get the current `HTTP::Cookie` for the given *key* or `nil` if none is set.
    #
    # ```
    # request = HTTP::Request.new "GET", "/"
    # request.cookies["foo"]? # => nil
    # request.cookies["foo"] = "bar"
    # request.cookies["foo"]?.try &.value # > "bar"
    # ```
    def []?(key)
      @cookies[key]?
    end

    # Returns `true` if a cookie with the given *key* exists.
    #
    # ```
    # request.cookies.has_key?("foo") # => true
    # ```
    def has_key?(key)
      @cookies.has_key?(key)
    end

    # Add the given *cookie* to this collection, overrides an existing cookie
    # with the same name if present.
    #
    # ```
    # response.cookies << HTTP::Cookie.new("foo", "bar", http_only: true)
    # ```
    def <<(cookie : Cookie)
      self[cookie.name] = cookie
    end

    # Yields each `HTTP::Cookie` in the collection.
    def each(&block : Cookie ->)
      @cookies.values.each do |cookie|
        yield cookie
      end
    end

    # Returns an iterator over the cookies of this collection.
    def each
      @cookies.each_value
    end

    # Whether the collection contains any cookies.
    def empty?
      @cookies.empty?
    end

    # Adds `Cookie` headers for the cookies in this collection to the
    # given `HTTP::Header` instance and returns it. Removes any existing
    # `Cookie` headers in it.
    def add_request_headers(headers)
      headers.delete("Cookie")
      headers.add("Cookie", map(&.to_cookie_header).join("; ")) unless empty?

      headers
    end

    # Adds `Set-Cookie` headers for the cookies in this collection to the
    # given `HTTP::Header` instance and returns it. Removes any existing
    # `Set-Cookie` headers in it.
    def add_response_headers(headers)
      headers.delete("Set-Cookie")
      each do |cookie|
        headers.add("Set-Cookie", cookie.to_set_cookie_header)
      end

      headers
    end

    # Returns this collection as a plain `Hash`.
    def to_h
      @cookies.dup
    end
  end
end