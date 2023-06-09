class NGHTTP::ParallelDownloader
  include Handler

  def call(env : HTTPEnv)
    if env.request?
      handle_request env
    elsif env.response?
      call_next env
    end
  end

  def handle_request(env)
    count = env.config["parallel"]?
    path = env.config["parallel_save"]?
    if !(count && path && env.request.method == "GET")
      return call_next env
    end
    count = count.as(Int32).to_i
    path = path.as(String)
    multi = false
    size = 0
    env.session.head url: env.request.uri.to_s, offset: 0...1 do |resp|
      if resp.status_code == 206
        multi = true
        if m = resp.headers.fetch("Content-Range", "").match(/bytes \d+-\d+\/(\d+)/i)
          size = m[1].to_i
        end # got size from range
      end   # 206?
    end     # head request
    if multi && size > 0
      env.int_config["parallel"] = true
      dispatch_multiple_requests env: env, size: size, count: count, path: path
    else
      call_next env
    end
  end

  alias Result = Tuple(Int32, Int32, String)

  def dispatch_multiple_requests(env, path, size, count)
    session = env.session
    partCount = count
    perPart = size//partCount
    perLastPart = size % partCount
    parts = Array(Tuple(Int32, Int32)).new
    start = 0
    # parts will hold a tuple {chunkSize,chunkOffset}
    # chunkOffset is the byte offset of this part
    # chunkSize is the length of data found in this chunk
    # you must add chunkSize to chunkOffset to get the end position to request in the http stream
    partCount.times do |p|
      t = {perPart, start}
      parts << t
      start += perPart
    end # parts
    t = {parts[-1][0] + perLastPart, parts[-1][1]}
    parts[-1] = t
    queue = Channel(Result).new(parts.size)
    parts.each_with_index do |part, idx|
      spawn_downloader env: env, queue: queue, path: path, index: idx, size: part[0], start: part[1]
    end
    t = {3, "init"}
    errors = Array(Tuple(Int32, String)).new(partCount, t)
    files = Array(String).new(parts.size, "")
    running = parts.size
    loop do
      idx, code, str = queue.receive
      running -= 1
      if code == 0
        t = {-1, ""}
        errors[idx] = t
        files[idx] = str
      else
        t = {errors[idx][0] + 1, str}
        errors[idx] = t
      end
      noErrors = errors.all? do |i|
        i[0] == -1
      end
      if noErrors
        merge_files files: files, path: path
        errors.clear
        break
      end
      retry_count = 0
      if errors[idx][0] != -1 && errors[idx][0] < retry_count
        running += 1
        spawn_downloader env: env, queue: queue, path: path, index: idx, start: parts[idx][1], size: parts[idx][0]
      end
      if running == 0
        break
      end
    end # while
    env.state = HTTPEnv::State::Response
    resp = env.response
    if errors.size > 0
      resp.status_code = 500
      txt = [] of String
      errors.each do |i|
        txt << i[-1]
      end # each
      raise HTTPError.new env, txt.join("\n")
    else
      resp.status_code = 200
      resp.body_io = TransparentIO.new File.open(path, "rb")
    end # if errors
  end   # def

  def spawn_downloader(env, queue, path, index, size, start)
    spawn do
      download(env: env, queue: queue, path: path, index: index, size: size, start: start)
    end
  end

  def merge_files(files, path)
    dst = File.open(path + ".temp", "wb")
    files.each do |i|
      src = File.open(i, "rb")
      IO.copy src, dst
      src.close
      File.delete i
    end
    dst.close
    File.rename(path + ".temp", path)
  end

  def download(env, queue, path, index, size, start)
    fn = sprintf "%s.%d-%d.p%03d", path, start, size, index
    if File.exists?(fn) && File.size(fn) == size
      t = {index, 0, fn}
      queue.send t
      return
    end
    fh = File.open(fn + ".temp", "wb")
    error = false
    begin
      download2(env: env, fh: fh, index: index, size: size, start: start)
      t = {index, 0, fn}
      queue.send t
    rescue e
      error = true
      es = e.inspect_with_backtrace
      t = {index, 1, es}
      queue.send t
    end
    fh.close
    if error
      File.delete fn + ".temp"
    else
      File.rename fn + ".temp", fn
    end # error?
  end   # def

  def download2(env, fh, index, start, size)
    env.session.get env.request.uri.to_s, offset: (start...start + size) do |resp|
      IO.copy(resp.body_io, fh)
    end # if
  end   # def

end # class
