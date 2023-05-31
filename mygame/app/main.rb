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
  end

  # Your own Tick function, can do everything here
  def tick(args)
    #input
    #iterate
    render
  end

  def input
    # we should always check the input first, before other logic
    # so that players don't get a 60ms lag
    # this is a local variable
    keyboard = @args.inputs.keyboard
    controller = @args.inputs.controller_one
    # check for game restart
    if @game_over && (keyboard.key_down.space || controller.key_down.start)
      $gtk.reset
    end
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
    spaceship_width = 45
    spaceship_height = 45
    spaceship_x_pos = 900 - (spaceship_width / 2)
    spaceship_y_pos = 200 - (spaceship_height / 2)

    @args.outputs.sprites << [spaceship_x_pos, spaceship_y_pos, spaceship_width, spaceship_height, 'sprites/ship_A.png']
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