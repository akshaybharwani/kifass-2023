# Helpful thing to erase the screen, might wanna take it out when publishing
$gtk.reset

# This is the only function that DragonRuby cares about. And it runs 60 times a second
# So that we don't have to worry about Delta time and stuff
def tick(args)
  # Only need to do this once, creating a new object
  args.state.game ||= TetrisGame.new(args)
  args.state.game.tick(args)
end

class TetrisGame
  def initialize(args)
    @args = args
    @score = 0
    @game_over = false
    @spaceship_speed = 10
  end

  # Your own Tick function, can do everything here
  def tick(args)
    input
    #iterate
    render
  end

  def input
    # we should always check the input first, before other logic
    # so that players don't get a 60ms lag
    # this is a local variable
    inputs = @args.inputs
    keyboard = @args.inputs.keyboard
    controller = @args.inputs.controller_one
    # check for game restart
    if @game_over && (keyboard.key_down.space || controller.key_down.start)
      $gtk.reset
    end

    # movement
    if inputs.up
      @args.state.spaceship.y += @spaceship_speed
    elsif inputs.down
      @args.state.spaceship.y -= @spaceship_speed
    end

    if inputs.left
      @args.state.spaceship.x -= @spaceship_speed
    elsif inputs.right
      @args.state.spaceship.x += @spaceship_speed
    end

    # movement
    if inputs.mouse.moved
      @args.state.spaceship.angle = (inputs.mouse.position.angle_from [@args.state.spaceship.x, @args.state.spaceship.y])
      # TODO: This sets the proper angle, figure out why
      @args.state.spaceship.angle -= 90
    end

    @args.outputs.debug << { x: 640, y: 25, text: @args.state.spaceship.angle, size_enum: -2, alignment_enum: 1, r: 255, g: 255, b: 255 }.label!
  end

  def iterate
    if @game_over
      return
    end
  end

  def render
    render_background
    render_sun
    render_planet
    render_spaceship
  end

  def render_background
    @args.outputs.solids << [0, 0, 1280, 720, 0, 0, 0]
  end

  def render_spaceship
    @args.state.spaceship.w ||= 45
    @args.state.spaceship.h ||= 45
    @args.state.spaceship.x ||= 900 - (@args.state.spaceship.w / 2)
    @args.state.spaceship.y ||= 200 - (@args.state.spaceship.h / 2)
    @args.state.spaceship.angle ||= 0


    @args.outputs.sprites << { x: @args.state.spaceship.x,
                              y: @args.state.spaceship.y,
                              w: @args.state.spaceship.w,
                              h: @args.state.spaceship.h,
                              path: 'sprites/ship_A.png',
                              angle: @args.state.spaceship.angle }
  end

  def render_planet
    @args.state.rotate_amount ||= 0
    @args.state.rotate_amount  += 1

    if @args.state.rotate_amount >= 360
      @args.state.rotate_amount = 0
    end

    planet_starting_position = {
      x: 640 + 150,
      y: 360 + 150
    }

    # rotate point around center screen
    rotate_point = @args.geometry.rotate_point planet_starting_position,
                                                 @args.state.rotate_amount,
                                                 x: 640, y: 360

    planet_width = 100
    planet_height = 100
    planet_x_pos = rotate_point.x - (planet_width / 2)
    planet_y_pos = rotate_point.y - (planet_height / 2)
    @args.outputs.sprites << [planet_x_pos, planet_y_pos, planet_width, planet_height, 'sprites/planet03.png']
  end

  def render_sun
    sun_width = 150
    sun_height = 150
    sun_x_pos = (1280 / 2) - (sun_width / 2)
    sun_y_pos = (720 / 2) - (sun_height / 2)
    @args.outputs.sprites << [sun_x_pos, sun_y_pos, sun_width, sun_height, 'sprites/sphere0.png', 0, 255, 255, 165, 0]
  end
end