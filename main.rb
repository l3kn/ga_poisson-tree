require "pqueue"

class Vec
  attr_accessor :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def norm_squared
    x * x + y * y
  end

  def norm
    Math.sqrt(norm_squared)
  end

  # Angle (in radiants) between the vector and the x axis
  def angle
    ns = norm
    x_ = @x / ns
    y_ = @y / ns

    Math.atan2(x_, y_)
  end
end

class ActiveSample
  # Sample Position
  attr_reader :x, :y

  # Number of children generated from this sample
  attr_accessor :n_children

  # Range (left & right) of the angle between parent and child sample
  attr_accessor :angle_range
  attr_reader :center_angle

  attr_reader :depth

  def initialize(x, y, angle_range, depth)
    @x = x
    @y = y
    @n_children = 0
    @angle_range = angle_range
    @depth = depth

    @center_angle = (@angle_range.begin + @angle_range.end) / 2
  end
end

class Poisson
  # Background grid and the size of each cell
  attr_reader :grid, :grid_size

  # List of active points
  attr_reader :active_points

  # List of all samples
  attr_reader :samples

  # Minimal distance between two points
  attr_reader :radius

  # Dimensions of the area
  attr_reader :size_x, :size_y

  # Number of retries before removing a point from the active list
  attr_reader :retries

  # Lines from seed sample to new sample
  attr_reader :lines

  # Number of children an active sample is allowed to have
  attr_reader :children_limit

  # Maximal angle between parent and child samples
  attr_reader :angle

  def initialize(size_x, size_y, radius, children_limit = 0, angle = 360.0)
    @size_x = size_x
    @size_y = size_y
    @radius = radius

    first_sample = [size_x / 2, size_y / 2]

    @active = PQueue.new([ActiveSample.new(
      first_sample[0],
      first_sample[1],
      0.0..(2.0 * Math::PI),
      0
    # )]) { |a, b| a.depth < b.depth }
    )]) { |a, b| a.center_angle < b.center_angle }
    @samples = [first_sample]
    @lines = []

    @retries = 5

    # Bounded so that there is at most one sample in each cell
    @grid_size = (@radius / Math.sqrt(2)).floor

    @grid = []

    # TODO: Why +1?
    ((@size_x / @grid_size) + 1).times do
      @grid << [nil] * (@size_y / @grid_size + 1)
    end

    @children_limit = children_limit

    @angle = angle / 180.0 * Math::PI
  end

  def insert_sample_into_grid(sample)
    x = sample[0] / @grid_size
    y = sample[1] / @grid_size

    # throw "Grid cell already contains a point" unless @grid[x][y].nil?
    return unless @grid[x][y].nil?

    @grid[x][y] = sample
  end

  def fill
    generate_new_sample until @active.empty?
  end

  def generate_new_sample
    current = @active.pop

    @retries.times do
      # distance = rand(1.0..1.2) * @radius
      factor = (current.x.to_f / 10800) * 2 + 1
      distance = rand(1.0..factor) * @radius

      direction = rand(current.angle_range)

      sample = [
        current.x + (Math.cos(direction) - Math.sin(direction)) * distance,
        current.y + (Math.sin(direction) + Math.cos(direction)) * distance
      ]

      if sample[0] >= 0 && sample[0] < @size_x &&
          sample[1] >= 0 && sample[1] < @size_y &&
          far_enough_from_neighbours?(sample)

        current.n_children += 1

        if @children_limit == 0 || current.n_children < @children_limit
          # Put the current sample back
          @active << current
        end

        @active << ActiveSample.new(
          sample[0],
          sample[1],
          (direction - @angle / 2)..(direction + @angle / 2),
          current.depth + 1
        )

        @samples << sample
        insert_sample_into_grid(sample)

        @lines << [[current.x, current.y], sample]

        break
      end
    end
  end

  def neigbours(sample)
    x = sample[0] / @grid_size
    y = sample[1] / @grid_size

    res = []

    (-2..2).each do |x_off|
      (-2..2).each do |y_off|
        x_ = x + x_off
        y_ = y + y_off

        if x_ >= 0 && y_ >= 0 && x_ < @grid.length && y_ < @grid[0].length
          res << grid[x_][y_] unless grid[x_][y_].nil?
        end
      end
    end

    res
  end

  def far_enough_from_neighbours?(sample)
    neigbours(sample).all? do |neigbour|
      dist_x = sample[0] - neigbour[0]
      dist_y = sample[1] - neigbour[1]
      distance = Math.sqrt(dist_x * dist_x + dist_y * dist_y)

      distance > @radius
    end
  end
end

poisson = Poisson.new(10800, 7200, 40, 10, 90)
# poisson = Poisson.new(10800, 7200, 20, 3, 120)
# poisson = Poisson.new(1000, 1000, 2, 3, 120)
poisson.fill

poisson.lines.each do |from, to|
  puts "L 1 #{from[0].round},#{from[1].round};#{to[0].round},#{to[1].round}"
end

# poisson.samples.each do |sample|
#   puts "C 1 1 5 #{sample[0].round},#{sample[1].round}"
# end
