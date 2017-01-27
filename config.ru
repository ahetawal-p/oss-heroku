use Rack::Static,
  :urls => ["/images", "/js", "/css"],
  :root => "html"

run lambda { |env|
  [
    200,
    {
      'Content-Type'  => 'text/html',
      'Cache-Control' => 'public, max-age=86400'
    },
    File.open('html/ahetawal-p.html', File::RDONLY)
  ]
}
