# nghttp

A client for HTTP goodness. Inspired by python-requests and daily need.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  nghttp:
    github: bmmcginty/nghttp
```

## Usage

```crystal
require "nghttp"
s=NGHTTP::Session.new
s.headers["User-Agent"]="New User-Agent"
s.config["cache"]=true
s.config["cache_expires"]=1.hours
body=nil
s.get"https://example.org/") do |resp|
body=resp.xml
end
```

## Development

Most work can be found in the handlers directory.

## Contributing

1. Fork it ( https://github.com/bmmcginty/nghttp/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [bmmcginty](https://github.com/bmmcginty) Brandon McGinty-Carroll - creator, maintainer
