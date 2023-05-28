# Helpful thing to erase the screen, might wanna take it out when publishing
$gtk.reset

class TetrisGame
  def initialize(args)
    # If the variable has not been set, set it to 0 with ||=
    @args = args
    @score = 0
    @game_over = false
    @grid_w = 10
    @grid_h = 20
    @next_move = 30
    @grid = []
    # for loop doesn't introduce a new scope unlike each,
    # variables defined in its block will be visible outside it, use each
    (0..@grid_w - 1).each do |x|
      @grid[x] = []
      (0..@grid_h - 1).each do |y|
        @grid[x][y] = 0
      end
    end
    @color_index = [
      [255, 127, 0],
      [0, 255, 255],
      [255, 255, 0],
      [128, 0, 128],
      [0, 255, 0],
      [255, 0, 0],
      [0, 0, 255],
      [127, 127, 127]
    ]

    # first create the current piece
    select_next_piece
    # do this again, to keep track of the next piece
    select_next_piece
  end

  # x and y are positions in the grid, not pixels
  def render_cube(pos_x, pos_y, color)
    box_size = 30
    # this centers the whole grid, the screen will always be 1280x720 for calculation purposes at least
    grid_x = (1280 - (@grid_w * box_size)) / 2
    grid_y = (720 - ((@grid_h - 2) * box_size)) / 2

    # This "args" needs to stay as this is the actual one for the engine
    @args.outputs.solids << [grid_x + (pos_x * box_size), (720 - grid_y) - (pos_y * box_size),
                             box_size, box_size, *@color_index[color]]
    @args.outputs.borders << [grid_x + (pos_x * box_size), (720 - grid_y) - (pos_y * box_size),
                             box_size, box_size, 255, 255, 255, 255]
  end

  def render_grid
    # Just remember to include "- 1" as "ruby doesn't work like C"
    # that is basically saying "go from 0 to arrayCount - 1"
    (0..@grid_w - 1).each do |x|
      (0..@grid_h - 1).each do |y|
        # render whatever color is on the grid
        render_cube(x, y, @grid[x][y]) if @grid[x][y] != 0
      end
    end
  end

  def render_grid_border(pos_x, pos_y, width, height)
    # if you just wanna use an array to the corresponding number of parameters, put a *color, and ruby will take care
    color = 7
    # renders the horizontal border
    (pos_x..(pos_x + width) - 1).each do |i|
      render_cube(i, pos_y, *color)
      render_cube(i, (pos_y + height) - 1, *color)
    end
    # renders the vertical border
    (pos_y..(pos_y + height) - 1).each do |j|
      render_cube(pos_x, j, *color)
      render_cube((pos_x + width) - 1, j, *color)
    end
  end

  def render_background
    #@args.outputs.sprites << [75, 300, 300, 300, 'console-logo.png']
    @args.outputs.solids << [0, 0, 1280, 720, 0, 0, 0]
    #render_grid_border(-1, -1, @grid_w + 2, @grid_h + 2)
  end

  def render_piece(piece, piece_x, piece_y)
    # iterating through the number of elements in the two-dimensional array
    (0..piece.length - 1).each do |x|
      # iterating for the count of elements (numbers) inside 1 element
      (0..piece[x].length - 1).each do |y|
        # x and y here specify which cubes to draw
        # current_piece x dnd y specify what location to draw at
        render_cube(piece_x + x, piece_y + y, piece[x][y]) if piece[x][y] != 0
      end
    end
  end

  def render_current_piece
    render_piece(@current_piece, @current_piece_x, @current_piece_y)
  end

  def render_next_piece
    render_grid_border(13, 2, 8, 8)
    # calculating the center
    center_x = (8 - @next_piece.length) / 2
    center_y = (8 - @next_piece[0].length) / 2
    render_piece(@next_piece, 13 + center_x, 2 + center_y)
    @args.outputs.labels << [900, 650, 'Next piece', 10, 255, 255, 255, 255]
  end

  def render_score
    @args.outputs.labels << [75, 75, "Score: #{@score}", 10, 255, 255, 255, 255]
    @args.outputs.labels << [200, 450, "GAME OVER", 100, 255, 255, 255, 255] if @game_over
  end

  def render
    render_background
    #render_grid
    #render_current_piece
    #render_next_piece
    #render_score
  end

  def current_piece_colliding
    # iterating through the number of elements in the two-dimensional array
    (0..@current_piece.length - 1).each do |x|
      # iterating for the count of elements (numbers) inside 1 element
      (0..@current_piece[x].length - 1).each do |y|
        # If any part is touching the grid
        if (@current_piece[x][y] != 0)
          if (@current_piece_y + y >= @grid_h - 1)
            return true
          # or if any part is touching any part of any planted piece
          elsif (@grid[@current_piece_x + x][@current_piece_y + y + 1] != 0)
            return true
          end
        end
      end
    end
    return false
  end

  def select_next_piece
    @current_piece = @next_piece
    # get a random number from 0 to 6 and set the current piece to that
    piece_number = rand(6) + 1
    # based on the random piece number, create a 2-dimensional array where 0 denotes an empty space (no color)
    # the piece_number denotes non-empty space (colored) which will be used to figure out color
    @next_piece = case piece_number
                     when 0 then [[0, piece_number], [0, piece_number], [piece_number, piece_number]]
                     when 1 then [[piece_number, piece_number], [0, piece_number], [0, piece_number]]
                     when 2 then [[piece_number, piece_number, piece_number, piece_number]]
                     when 3 then [[piece_number, 0], [piece_number, piece_number], [0, piece_number]]
                     when 4 then [[0, piece_number], [piece_number, piece_number], [piece_number, 0]]
                     when 5 then [[piece_number, piece_number], [piece_number, piece_number]]
                     when 6 then [[0, piece_number], [piece_number, piece_number], [0, piece_number]]
                     end
    # set piece initial position
    @current_piece_x = 5
    @current_piece_y = 0
  end

  def plant_current_piece
    # iterating through the number of elements in the two-dimensional array
    (0..@current_piece.length - 1).each do |x|
      # iterating for the count of elements (numbers) inside 1 element
      (0..@current_piece[x].length - 1).each do |y|
        if @current_piece[x][y] != 0
          # make this part of the landscape
          @grid[@current_piece_x + x][@current_piece_y + y] = @current_piece[x][y]
        end
      end
    end

    # see if any rows need to be cleared out
    (0..@grid_h - 1).each do |y|
      full = true
      (0..@grid_w - 1).each do |x|
        # if any grid block is empty, then can't clear the row
        if @grid[x][y] == 0
          full = false
          break
        end
      end
      if full # no empty space in the row, nuke it!
        @score += 1
        # in a scenario where y < 0, the ruby magic here works as going down from y to 1
        y.downto(1).each do |i|
          (0..@grid_w-1).each do |j|
            # shift all the rows below by 1 row
            @grid[j][i] = @grid[j][i - 1]
          end
        end
        (0..@grid_w - 1).each do |i|
          # make the top row of the grid 0 as we shifted everything down
          @grid[i][0] = 0
        end
      end
    end
    # reset the new piece position and get a new piece
    select_next_piece
    if current_piece_colliding
      @game_over = true
    end
  end

  def input
    # we should always check the input first, before other logic
    # so that players don't get a 60ms lag
    # this is a local variable
    keyboard = @args.inputs.keyboard
    controller = @args.inputs.controller_one
    # check for game restart
    # move the piece left
    if @game_over && (keyboard.key_down.space || controller.key_down.start)
      $gtk.reset
    end

    # move the piece left
    if keyboard.key_down.left || controller.key_down.left
      if @current_piece_x > 0
        @current_piece_x -= 1
      end
    end
    # move the piece right
    if keyboard.key_down.right || controller.key_down.right
      if @current_piece_x + @current_piece.length < @grid_w
        @current_piece_x += 1
      end
    end
    # make the piece go down faster
    if keyboard.key_held.down || keyboard.key_down.down || controller.key_held.down || controller.key_down.down
      @next_move -= 10
    end
    # rotate piece left
    if keyboard.key_down.a || controller.key_down.x
      rotate_current_piece_left
    end
    # rotate piece right
    if keyboard.key_down.d || controller.key_down.b
      rotate_current_piece_right
    end
  end

  def rotate_current_piece_left
    @current_piece = @current_piece.transpose.map(&:reverse)
    # when doing transpose the dimensions of the array may change (lookup more about this)
    # so we have to take into account the length of rotated piece
    # so if after rotation the position including length is beyond grid, clamp it
    if (@current_piece_x + @current_piece.length) >= @grid_w
      @current_piece_x = @grid_w - @current_piece.length
    end
  end

  def rotate_current_piece_right
    @current_piece = @current_piece.transpose.map(&:reverse)
    @current_piece = @current_piece.transpose.map(&:reverse)
    @current_piece = @current_piece.transpose.map(&:reverse)
    if (@current_piece_x + @current_piece.length) >= @grid_w
      @current_piece_x = @grid_w - @current_piece.length
    end
  end

  def iterate
    if @game_over
      return
    end
    @next_move -= 1
    # 30 second countdown, so every half a second
    if @next_move <= 0 # drop the piece!
      if current_piece_colliding
        plant_current_piece
      else
        @current_piece_y += 1
      end
      # reset countdown
      @next_move = 30
    end
  end

  # Your own Tick function, can do everything here
  def tick
    #input
    #iterate
    render
  end
end

# This is the only function that DragonRuby cares about. And it runs 60 times a second
# So that we don't have to worry about Delta time and stuff
def tick(args)
  # Only need to do this once, creating a new object
  args.state.game ||= TetrisGame.new(args)
  args.state.game.tick
end
