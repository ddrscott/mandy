require "option_parser"

# To make docker play nice
Signal::INT.trap { exit 1 }
Signal::TERM.trap { exit 1 }

ANSI_MAP = %w(@ 0 # % X x o * + - . . .)
MIN_ZOOM = 2.0e-13

# Formula from https://www.mathworks.com/help/distcomp/examples/illustrating-three-approaches-to-gpu-computing-the-mandelbrot-set.html?s_tid=gn_loc_drop#d119e4796
def mandelbrot(real0, img0, max)
  real = real0
  img = img0
  count = 0
  while count < max && real * real + img * img <= 4.0
    count += 1
    old_r = real
    real = real * real - img * img + real0
    img = 2.0 * old_r * img + img0
  end
  return count
end

def render(left, right, top, bottom, step_x, step_y, max) String
  result = [] of String
  result << "\e[2J\e[0;0H"
  top.step(to: bottom, by: step_y) do |y|
    # puts "y: #{y}"
    left.step(to: right, by: step_x) do |x|
      # puts "    x: #{x}"
      loops = mandelbrot(x, y, max)
      if loops == max
        result << " "
      elsif loops == 0
        result << ANSI_MAP[0]
      else
        c = loops.fdiv(max) * ANSI_MAP.size
        result << ANSI_MAP[c.to_i]
      end
    end
    result << "\n"
  end
  result[0, result.size - 1].join
end

def zoomer(rows, cols, mid_x, mid_y, zoom, max : Int32) String

  mid_x0, mid_y0, zoom0, max0 = mid_x, mid_y, zoom, max
  size            = `stty size`.split
  view_width, view_height = cols.to_i - 1, rows.to_i - 3

  # use alternate terminal screen output
  # print "\e[?47h"
  input = ' '
  while input != 'q'
    # scaled y coordinate of pixel (must be scaled to lie somewhere in the mandelbrot Y scale (-1, 1)
    scale_h = view_height * 0.5 / view_height * 2.0 * zoom
    scale_w =  view_width * 0.5 /  view_width * 3.5 * zoom

    top    = -scale_h - mid_y
    bottom =  scale_h - mid_y
    left   = -scale_w - mid_x
    right  =  scale_w - mid_x

    step_x = (right - left) / view_width
    step_y = (bottom - top) / view_height

    zoom = [MIN_ZOOM, zoom].max
    # increase iterations as zoom gets deeper
    max_adj = (Math.log(1/zoom).abs * 8).to_i

    puts render(left: left, right: right, top: top, bottom: bottom, step_x: step_x, step_y: step_y, max: max + max_adj)
    print "\e[1;32m pan: w/a/s/d h/j/k/l, zoom: i=in, o=out, r=reset, iterations: =: more, -: less, quit: q\n"
    print "\e[1;36m -x #{mid_x} -y #{mid_y} -z #{zoom} --max #{max}"
    print "\e[0m" # reset colors

    inc = [step_x.abs, step_y.abs].max
    input = STDIN.raw &.read_char
    case input
    when 'd', 'l'
      mid_x -= step_x * 2
    when 's', 'j'
      mid_y -= step_y * 2
    when 'w', 'k'
      mid_y += step_y * 2
    when 'a', 'h'
      mid_x += step_x * 2
    when 'i'
      zoom *= 0.96
    when 'o'
      zoom *= 1.04
    when 'I'
      zoom *= 0.8
    when 'O'
      zoom *= 1.2
    when 'r'
      mid_x, mid_y, zoom, max = mid_x0, mid_y0, zoom0, max0
    when '='
      max += 1
    when '-'
      max -= 1
    end
  end
ensure
  print "\e[?47l"     # switch back to primary screen
end

# Defaults
x     = 0.75
y     =  0.0
zoom  =  1.0
max   =  100
fps   = -1.0
delay = -1.0
cols  = 80
rows  = 25
OptionParser.parse! do |parser|
  parser.banner = "Usage: mandelbrot [arguments]"
  parser.on("-r ROWS", "--rows=ROWS", "tty rows") { |val| rows = val.to_f }
  parser.on("-c COLS", "--cols=COLS", "tty cols") { |val| cols = val.to_f }
  parser.on("-z ZOOM", "--zoom=ZOOM", "initial zoom") { |val| zoom = val.to_f }
  parser.on("-x X", "center point X") { |val| x = val.to_f }
  parser.on("-y Y", "center point Y") { |val| y = val.to_f }
  parser.on("-z ZOOM", "--zoom=ZOOM", "initial zoom") { |val| zoom = val.to_f }
  parser.on("--max MAX", "--max=MAX", "max iterations") { |val| max = val.to_i }
  parser.on("--fps=FPS", "max FPS") { |val| delay = 1.0 / val.to_f }
  parser.on("--help", "Show this help") do
    puts parser
    exit(0)
  end
end

zoomer(rows: rows, cols: cols, mid_x: x, mid_y: y, zoom: zoom, max: max)
# -x 0.7495500935639509 -y -0.0637199391725012 -z 1.6e-13 --max 100
# -x 0.7494718949168628 -y -0.1077071806664979 -z 2.5e-13 --max 100
# -x 0.3764323855702480 -y -0.6722880311475035 -z 1.8e-13 --max 100
# -x 0.7288780059956085 -y -0.2920316017316762 -z 1.6e-13 --max 100
# -x 0.7494718949175094 -y -0.10770718066611382 -z 2e-13 --max 100
